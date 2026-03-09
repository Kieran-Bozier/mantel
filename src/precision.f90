module precision

    !>      This module defines the precision for real
    !>      and integer types used in the project

    use, intrinsic          ::      iso_c_binding
    implicit none

    integer, parameter      ::      dp = c_double
    integer, parameter      ::      sp = c_float
    integer, parameter      ::      ic = c_int
end module precision