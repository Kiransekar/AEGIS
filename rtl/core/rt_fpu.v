module rt_fpu #(parameter DATA_WIDTH=32)(
    input wire i_clk, input wire i_rst_n,
    input wire [3:0] i_fpu_op,
    input wire [DATA_WIDTH-1:0] i_operand_a, i_operand_b,
    input wire i_valid,
    output wire [DATA_WIDTH-1:0] o_result,
    output wire o_valid,
    output wire o_fflags_invalid, o_fflags_divzero, o_fflags_overflow, o_fflags_underflow, o_fflags_inexact,
    input wire i_ftz_enable,
    output wire [DATA_WIDTH-1:0] o_int_result,
    input wire [DATA_WIDTH-1:0] i_int_operand,
    output wire o_wb_int
);

    wire sign_a=i_operand_a[31], sign_b=i_operand_b[31];
    wire [7:0] exp_a=i_operand_a[30:23], exp_b=i_operand_b[30:23];
    wire [22:0] mant_a=i_operand_a[22:0], mant_b=i_operand_b[22:0];
    wire is_zero_a=(exp_a==0)&&(mant_a==0), is_zero_b=(exp_b==0)&&(mant_b==0);
    wire is_subnormal_a=(exp_a==0)&&(mant_a!=0), is_subnormal_b=(exp_b==0)&&(mant_b!=0);
    wire is_inf_a=(exp_a==255)&&(mant_a==0), is_inf_b=(exp_b==255)&&(mant_b==0);
    wire is_nan_a=(exp_a==255)&&(mant_a!=0), is_nan_b=(exp_b==255)&&(mant_b!=0);

    wire [31:0] ftz_a=(i_ftz_enable&&is_subnormal_a)?{sign_a,31'd0}:i_operand_a;
    wire [31:0] ftz_b=(i_ftz_enable&&is_subnormal_b)?{sign_b,31'd0}:i_operand_b;
    wire ftz_sign_a=ftz_a[31], ftz_sign_b=ftz_b[31];
    wire [7:0] ftz_exp_a=ftz_a[30:23], ftz_exp_b=ftz_b[30:23];
    wire [22:0] ftz_mant_a=ftz_a[22:0], ftz_mant_b=ftz_b[22:0];
    wire [23:0] full_mant_a={(ftz_exp_a!=0),ftz_mant_a}, full_mant_b={(ftz_exp_b!=0),ftz_mant_b};

    function [4:0] count_lz; input [24:0] v; begin
        if(v[23])count_lz=0;else if(v[22])count_lz=1;else if(v[21])count_lz=2;
        else if(v[20])count_lz=3;else if(v[19])count_lz=4;else if(v[18])count_lz=5;
        else if(v[17])count_lz=6;else if(v[16])count_lz=7;else if(v[15])count_lz=8;
        else if(v[14])count_lz=9;else if(v[13])count_lz=10;else if(v[12])count_lz=11;
        else if(v[11])count_lz=12;else if(v[10])count_lz=13;else if(v[9])count_lz=14;
        else if(v[8])count_lz=15;else if(v[7])count_lz=16;else if(v[6])count_lz=17;
        else if(v[5])count_lz=18;else if(v[4])count_lz=19;else if(v[3])count_lz=20;
        else if(v[2])count_lz=21;else if(v[1])count_lz=22;else if(v[0])count_lz=23;
        else count_lz=24;
    end endfunction

    function [31:0] norm_pack; input [24:0] rm; input [7:0] re; input rs;
        reg [24:0] m; reg [7:0] e; reg [4:0] lz; begin
        m=rm; e=re;
        if(m[24]&&e<254)begin m=m>>1; e=e+1; end
        if(!m[23]&&m!=0)begin lz=count_lz(m);
            if({3'd0,lz}<e)begin m=m<<lz; e=e-{3'd0,lz}; end
            else if(e>1)begin m=m<<(e-1); e=1; end
            else e=0;
        end
        if(e==0||m==0) norm_pack={rs,31'd0};
        else if(e>=255) norm_pack={rs,8'hFF,23'd0};
        else norm_pack={rs,e,m[22:0]};
    end endfunction

    localparam [3:0] FPU_FLW=0,FPU_FSW=1,FPU_FADD=2,FPU_FSUB=3,FPU_FMUL=4,
        FPU_FDIV=5,FPU_FSQRT=6,FPU_FMIN=7,FPU_FMAX=8,FPU_FSGNJ=9,
        FPU_FSGNJN=10,FPU_FSGNJX=11,FPU_CVTWS=12,FPU_CVTSW=13,FPU_MVXW=14,FPU_MVWX=15;
    wire [31:0] CNAN=32'h7FC00000;

    // FADD/FSUB alignment
    wire add_a_lg=(ftz_exp_a>=ftz_exp_b);
    wire [7:0] add_be=add_a_lg?ftz_exp_a:ftz_exp_b;
    wire [7:0] add_ed=add_a_lg?(ftz_exp_a-ftz_exp_b):(ftz_exp_b-ftz_exp_a);
    wire [23:0] add_aa=add_a_lg?full_mant_a:(add_ed<24?(full_mant_a>>add_ed[4:0]):24'd0);
    wire [23:0] add_ab=add_a_lg?(add_ed<24?(full_mant_b>>add_ed[4:0]):24'd0):full_mant_b;
    wire add_ss=(ftz_sign_a==ftz_sign_b);
    wire [24:0] add_sum={1'b0,add_aa}+{1'b0,add_ab};
    wire add_age=(ftz_exp_a>ftz_exp_b)||(ftz_exp_a==ftz_exp_b&&full_mant_a>=full_mant_b);
    wire [24:0] add_dif=add_age?({1'b0,add_aa}-{1'b0,add_ab}):({1'b0,add_ab}-{1'b0,add_aa});
    // FADD
    wire [24:0] fadd_rm=add_ss?add_sum:add_dif;
    wire fadd_rs=add_ss?ftz_sign_a:(add_age?ftz_sign_a:ftz_sign_b);
    wire [31:0] fadd_n=norm_pack(fadd_rm,add_be,fadd_rs);
    wire [31:0] fadd_r=(is_nan_a||is_nan_b)?CNAN:(is_inf_a&&is_inf_b&&ftz_sign_a!=ftz_sign_b)?CNAN:is_inf_a?ftz_a:is_inf_b?ftz_b:fadd_n;
    wire fadd_iv=(is_nan_a||is_nan_b)||(is_inf_a&&is_inf_b&&ftz_sign_a!=ftz_sign_b);
    // FSUB
    wire fsub_ea=(ftz_sign_a!=ftz_sign_b);
    wire [24:0] fsub_rm=fsub_ea?add_sum:add_dif;
    wire fsub_rs=fsub_ea?ftz_sign_a:(add_age?ftz_sign_a:~ftz_sign_a);
    wire [31:0] fsub_n=norm_pack(fsub_rm,add_be,fsub_rs);
    wire [31:0] fsub_r=(is_nan_a||is_nan_b)?CNAN:(is_inf_a&&is_inf_b&&ftz_sign_a==ftz_sign_b)?CNAN:is_inf_a?ftz_a:is_inf_b?{~ftz_sign_b,ftz_exp_b,ftz_mant_b}:fsub_n;
    wire fsub_iv=(is_nan_a||is_nan_b)||(is_inf_a&&is_inf_b&&ftz_sign_a==ftz_sign_b);

    // FMUL
    wire [47:0] mp=full_mant_a*full_mant_b;
    wire ms=ftz_sign_a^ftz_sign_b, mc=mp[47];
    wire [7:0] me=ftz_exp_a+ftz_exp_b-127+(mc?1:0);
    wire [22:0] mm=mc?mp[46:24]:mp[45:23];
    wire [31:0] mn=(me>=255)?{ms,8'hFF,23'd0}:(me<=1)?{ms,31'd0}:{ms,me,mm};
    wire [31:0] fmul_r=(is_nan_a||is_nan_b)?CNAN:((is_inf_a&&is_zero_b)||(is_zero_a&&is_inf_b))?CNAN:(is_inf_a||is_inf_b)?{ms,8'hFF,23'd0}:(is_zero_a||is_zero_b)?{ms,31'd0}:mn;
    wire fmul_iv=(is_nan_a||is_nan_b)||((is_inf_a&&is_zero_b)||(is_zero_a&&is_inf_b));

    // FDIV
    wire ds=ftz_sign_a^ftz_sign_b;
    wire [31:0] fdiv_r=(is_nan_a||is_nan_b)?CNAN:(is_zero_b&&!is_zero_a)?{ds,8'hFF,23'd0}:(is_zero_a&&is_zero_b)?CNAN:(is_inf_a&&is_inf_b)?CNAN:is_inf_a?{ds,8'hFF,23'd0}:is_inf_b?{ds,31'd0}:{ds,8'd127,23'd0};
    wire fdiv_iv=(is_nan_a||is_nan_b)||(is_zero_a&&is_zero_b)||(is_inf_a&&is_inf_b);
    wire fdiv_dz=is_zero_b&&!is_zero_a&&!is_nan_a&&!is_nan_b;

    // FMIN/FMAX
    wire altb=(ftz_sign_a!=ftz_sign_b)?ftz_sign_a:ftz_sign_a?((ftz_exp_a>ftz_exp_b)||(ftz_exp_a==ftz_exp_b&&full_mant_a>full_mant_b)):((ftz_exp_a<ftz_exp_b)||(ftz_exp_a==ftz_exp_b&&full_mant_a<full_mant_b));
    wire [31:0] fmin_r=(is_nan_a||is_nan_b)?CNAN:altb?ftz_a:ftz_b;
    wire [31:0] fmax_r=(is_nan_a||is_nan_b)?CNAN:altb?ftz_b:ftz_a;
    wire fmm_iv=is_nan_a||is_nan_b;

    // FSGNJ
    wire [31:0] fsgnj_r={i_operand_b[31],i_operand_a[30:0]};
    wire [31:0] fsgnjn_r={~i_operand_b[31],i_operand_a[30:0]};
    wire [31:0] fsgnjx_r={i_operand_a[31]^i_operand_b[31],i_operand_a[30:0]};

    // FCVT.W.S
    wire [7:0] csh=(ftz_exp_a>=150)?8'd0:(150-ftz_exp_a);
    wire [31:0] cip=(ftz_exp_a>=127)?({1'b0,full_mant_a,8'd0}>>csh[4:0]):32'd0;
    wire [31:0] cir=ftz_sign_a?(-cip):cip;
    wire [31:0] fcvt_i=(is_nan_a||is_inf_a)?32'h7FFFFFFF:(is_zero_a||is_subnormal_a)?32'd0:cir;
    wire fcvt_iv=is_nan_a||is_inf_a;

    // FMV
    wire [31:0] fmvxw_i=i_operand_a;
    wire [31:0] fmvwx_r=i_int_operand;

    // Result MUX
    wire [31:0] fpu_result, int_result_comb;
    wire wb_int_comb, fi_comb, fd_comb, fo_comb, fu_comb, fx_comb;
    assign {fpu_result,int_result_comb,wb_int_comb,fi_comb,fd_comb,fo_comb,fu_comb,fx_comb}=
        (i_fpu_op==FPU_FADD)?{fadd_r,32'd0,1'b0,fadd_iv,1'b0,1'b0,1'b0,1'b0}:
        (i_fpu_op==FPU_FSUB)?{fsub_r,32'd0,1'b0,fsub_iv,1'b0,1'b0,1'b0,1'b0}:
        (i_fpu_op==FPU_FMUL)?{fmul_r,32'd0,1'b0,fmul_iv,1'b0,1'b0,1'b0,1'b0}:
        (i_fpu_op==FPU_FDIV)?{fdiv_r,32'd0,1'b0,fdiv_iv,fdiv_dz,1'b0,1'b0,1'b0}:
        (i_fpu_op==FPU_FMIN)?{fmin_r,32'd0,1'b0,fmm_iv,1'b0,1'b0,1'b0,1'b0}:
        (i_fpu_op==FPU_FMAX)?{fmax_r,32'd0,1'b0,fmm_iv,1'b0,1'b0,1'b0,1'b0}:
        (i_fpu_op==FPU_FSGNJ)?{fsgnj_r,32'd0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}:
        (i_fpu_op==FPU_FSGNJN)?{fsgnjn_r,32'd0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}:
        (i_fpu_op==FPU_FSGNJX)?{fsgnjx_r,32'd0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}:
        (i_fpu_op==FPU_CVTWS)?{32'd0,fcvt_i,1'b1,fcvt_iv,1'b0,1'b0,1'b0,1'b0}:
        (i_fpu_op==FPU_CVTSW)?{i_int_operand,32'd0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}:
        (i_fpu_op==FPU_MVXW)?{32'd0,fmvxw_i,1'b1,1'b0,1'b0,1'b0,1'b0,1'b0}:
        (i_fpu_op==FPU_MVWX)?{fmvwx_r,32'd0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}:
        (i_fpu_op==FPU_FLW||i_fpu_op==FPU_FSW)?{i_operand_a,32'd0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}:
        {CNAN,32'd0,1'b0,1'b1,1'b0,1'b0,1'b0,1'b0};

    // Output registration
    reg [31:0] rq,irq; reg vq,wiq,fiq,fdq,foq,fuq,fxq;
    always @(posedge i_clk or negedge i_rst_n) begin
        if(!i_rst_n) begin rq<=0;irq<=0;vq<=0;wiq<=0;fiq<=0;fdq<=0;foq<=0;fuq<=0;fxq<=0; end
        else if(i_valid) begin rq<=fpu_result;irq<=int_result_comb;vq<=1;wiq<=wb_int_comb;
            fiq<=fi_comb;fdq<=fd_comb;foq<=fo_comb;fuq<=fu_comb;fxq<=fx_comb; end
    end
    assign o_result=rq; assign o_int_result=irq; assign o_valid=vq; assign o_wb_int=wiq;
    assign o_fflags_invalid=fiq; assign o_fflags_divzero=fdq;
    assign o_fflags_overflow=foq; assign o_fflags_underflow=fuq; assign o_fflags_inexact=fxq;
endmodule
