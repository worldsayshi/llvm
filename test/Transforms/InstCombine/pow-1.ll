; Test that the pow library call simplifier works correctly.
;
; RUN: opt < %s -instcombine -S | FileCheck %s
; rdar://7251832

; NOTE: The readonly attribute on the pow call should be preserved
; in the cases below where pow is transformed into another function call.

declare float @powf(float, float) nounwind readonly
declare double @pow(double, double) nounwind readonly

; Check pow(1.0, x) -> 1.0.

define float @test_simplify1(float %x) {
; CHECK: @test_simplify1
  %retval = call float @powf(float 1.0, float %x)
  ret float %retval
; CHECK-NEXT: ret float 1.000000e+00
}

define double @test_simplify2(double %x) {
; CHECK: @test_simplify2
  %retval = call double @pow(double 1.0, double %x)
  ret double %retval
; CHECK-NEXT: ret double 1.000000e+00
}

; Check pow(2.0, x) -> exp2(x).

define float @test_simplify3(float %x) {
; CHECK: @test_simplify3
  %retval = call float @powf(float 2.0, float %x)
; CHECK-NEXT: [[EXP2F:%[a-z0-9]+]] = call float @exp2f(float %x) nounwind readonly
  ret float %retval
; CHECK-NEXT: ret float [[EXP2F]]
}

define double @test_simplify4(double %x) {
; CHECK: @test_simplify4
  %retval = call double @pow(double 2.0, double %x)
; CHECK-NEXT: [[EXP2:%[a-z0-9]+]] = call double @exp2(double %x) nounwind readonly
  ret double %retval
; CHECK-NEXT: ret double [[EXP2]]
}

; Check pow(x, 0.0) -> 1.0.

define float @test_simplify5(float %x) {
; CHECK: @test_simplify5
  %retval = call float @powf(float %x, float 0.0)
  ret float %retval
; CHECK-NEXT: ret float 1.000000e+00
}

define double @test_simplify6(double %x) {
; CHECK: @test_simplify6
  %retval = call double @pow(double %x, double 0.0)
  ret double %retval
; CHECK-NEXT: ret double 1.000000e+00
}

; Check pow(x, 0.5) -> fabs(sqrt(x)), where x != -infinity.

define float @test_simplify7(float %x) {
; CHECK: @test_simplify7
  %retval = call float @powf(float %x, float 0.5)
; CHECK-NEXT: [[SQRTF:%[a-z0-9]+]] = call float @sqrtf(float %x) nounwind readonly
; CHECK-NEXT: [[FABSF:%[a-z0-9]+]] = call float @fabsf(float [[SQRTF]]) nounwind readonly
; CHECK-NEXT: [[FCMP:%[a-z0-9]+]] = fcmp oeq float %x, 0xFFF0000000000000
; CHECK-NEXT: [[SELECT:%[a-z0-9]+]] = select i1 [[FCMP]], float 0x7FF0000000000000, float [[FABSF]]
  ret float %retval
; CHECK-NEXT: ret float [[SELECT]]
}

define double @test_simplify8(double %x) {
; CHECK: @test_simplify8
  %retval = call double @pow(double %x, double 0.5)
; CHECK-NEXT: [[SQRT:%[a-z0-9]+]] = call double @sqrt(double %x) nounwind readonly
; CHECK-NEXT: [[FABS:%[a-z0-9]+]] = call double @fabs(double [[SQRT]]) nounwind readonly
; CHECK-NEXT: [[FCMP:%[a-z0-9]+]] = fcmp oeq double %x, 0xFFF0000000000000
; CHECK-NEXT: [[SELECT:%[a-z0-9]+]] = select i1 [[FCMP]], double 0x7FF0000000000000, double [[FABS]]
  ret double %retval
; CHECK-NEXT: ret double [[SELECT]]
}

; Check pow(-infinity, 0.5) -> +infinity.

define float @test_simplify9(float %x) {
; CHECK: @test_simplify9
  %retval = call float @powf(float 0xFFF0000000000000, float 0.5)
  ret float %retval
; CHECK-NEXT: ret float 0x7FF0000000000000
}

define double @test_simplify10(double %x) {
; CHECK: @test_simplify10
  %retval = call double @pow(double 0xFFF0000000000000, double 0.5)
  ret double %retval
; CHECK-NEXT: ret double 0x7FF0000000000000
}

; Check pow(x, 1.0) -> x.

define float @test_simplify11(float %x) {
; CHECK: @test_simplify11
  %retval = call float @powf(float %x, float 1.0)
  ret float %retval
; CHECK-NEXT: ret float %x
}

define double @test_simplify12(double %x) {
; CHECK: @test_simplify12
  %retval = call double @pow(double %x, double 1.0)
  ret double %retval
; CHECK-NEXT: ret double %x
}

; Check pow(x, 2.0) -> x*x.

define float @test_simplify13(float %x) {
; CHECK: @test_simplify13
  %retval = call float @powf(float %x, float 2.0)
; CHECK-NEXT: [[SQUARE:%[a-z0-9]+]] = fmul float %x, %x
  ret float %retval
; CHECK-NEXT: ret float [[SQUARE]]
}

define double @test_simplify14(double %x) {
; CHECK: @test_simplify14
  %retval = call double @pow(double %x, double 2.0)
; CHECK-NEXT: [[SQUARE:%[a-z0-9]+]] = fmul double %x, %x
  ret double %retval
; CHECK-NEXT: ret double [[SQUARE]]
}

; Check pow(x, -1.0) -> 1.0/x.

define float @test_simplify15(float %x) {
; CHECK: @test_simplify15
  %retval = call float @powf(float %x, float -1.0)
; CHECK-NEXT: [[RECIPROCAL:%[a-z0-9]+]] = fdiv float 1.000000e+00, %x
  ret float %retval
; CHECK-NEXT: ret float [[RECIPROCAL]]
}

define double @test_simplify16(double %x) {
; CHECK: @test_simplify16
  %retval = call double @pow(double %x, double -1.0)
; CHECK-NEXT: [[RECIPROCAL:%[a-z0-9]+]] = fdiv double 1.000000e+00, %x
  ret double %retval
; CHECK-NEXT: ret double [[RECIPROCAL]]
}
