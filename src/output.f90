module output

    !>      This module handle all output formatting written 
    !>      to stdout, including the banner, section headers, 
    !>      and formatted data output.

    use precision,              only: dp
    implicit none

    !> Stdout output unit
    integer, parameter         :: stdout = 6

    !> Format strings as constants for consistency
    character(len=*), parameter :: fmt_header  = "(/,5x,A)"
    character(len=*), parameter :: fmt_divider = "(5x,70('-'))"
    character(len=*), parameter :: fmt_float   = "(5x,A30,2x,F14.8)"
    character(len=*), parameter :: fmt_int     = "(5x,A30,2x,I10)"
    character(len=*), parameter :: fmt_vec     = "(5x,A30,3(2x,F12.6))"
    character(len=*), parameter :: fmt_int_vec = "(5x,A30,3(2x,I10))"
    character(len=*), parameter :: fmt_msg     = "(5x,A)"


contains
    

    subroutine print_banner
        !> Prints the program banner
        write(stdout, *)
        write(stdout, '(5x,"                   ▗▖  ▗▖▗▄▄▄▖▗▖ ▗▖▗▄▄▄▖▗▄▄▄▖▗▖   ")')
        write(stdout, '(5x,"                   ▐▛▚▞▜▌▐▌ ▐▌▐▛▖▐▌ ▐▌  ▐▌   ▐▌   ")')
        write(stdout, '(5x,"                   ▐▌▝▘▐▌▐▛▀▜▌▐▌▝▟▌ ▐▌  ▐▛▀▘ ▐▌   ")')
        write(stdout, '(5x,"                   ▐▌  ▐▌▐▌ ▐▌▐▌ ▐▌ ▐▌  ▐▙▄▄▖▐▙▄▄▖")')
        write(stdout, '(5x,"     =====================================================")')
        write(stdout, '(5x, "                                           ")')
        write(stdout, '(5x,"                   Bloch basis evaluation of the    ")')
        write(stdout, '(5x,"                    screened Coulomb interaction     ")')
        write(stdout, '(5x,"     =====================================================")')
        write(stdout, '(5x,"                       Written by K. Bozier            ")')
        write(stdout, '(5x,"                             2026                   ")')
        write(stdout, *)
        flush(stdout)
    end subroutine print_banner

    !> Prints a section header with lines
    subroutine print_section_header(title)
        character(len=*), intent(in) :: title
        write(stdout, *)
        write(stdout, fmt_divider)
        write(stdout, fmt_header) trim(title)
        write(stdout, fmt_divider)
        flush(stdout)
    end subroutine print_section_header

    subroutine print_int_vec(label, vec)
        !> Prints a 3D vector
        character(len=*), intent(in) :: label
        integer, intent(in)         :: vec(3)
        
        write(stdout, fmt_int_vec) trim(label), vec(1), vec(2), vec(3)
        flush(stdout)
    end subroutine print_int_vec

    !> Prints a 3x3 matrix (like lattice vectors)
    subroutine print_matrix(label, mat)
        character(len=*), intent(in) :: label
        real(dp), intent(in)         :: mat(3,3)
        integer                      :: i
        
        write(stdout, *)
        write(stdout, fmt_msg) trim(label) // ":"
        do i = 1, 3
            write(stdout, "(10x,3(1x,F14.9))") mat(i,:)
        end do
        flush(stdout)
    end subroutine print_matrix

    !> Prints a labeled integer
    subroutine print_info_int(label, val)
        character(len=*), intent(in) :: label
        integer, intent(in)          :: val
        write(stdout, fmt_int) label, val
        flush(stdout)
    end subroutine print_info_int

    !> Prints a labeled float
    subroutine print_info_real(label, val)
        character(len=*), intent(in) :: label
        real(dp), intent(in)         :: val
        write(stdout, fmt_float) label, val
        flush(stdout)
    end subroutine print_info_real

    !> Prints a generic message
    subroutine print_msg(msg)
        character(len=*), intent(in) :: msg
        write(stdout, fmt_msg) trim(msg)
        flush(stdout)
    end subroutine print_msg





    !> Simple timer report
    subroutine print_clock(label, start_time, end_time)
        character(len=*), intent(in) :: label
        real(dp), intent(in)         :: start_time, end_time
        write(stdout, "(5x,A50,F12.4,' s')") trim(label)//" :", (end_time - start_time)
        flush(stdout)
    end subroutine print_clock

end module output