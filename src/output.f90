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
        write(stdout, '(5x,"                           2025 - 2026                   ")')
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


    !> Obtain and print memory estimates
    subroutine print_memory_estimate(nx, ny, nz, numBands, numK, numG, numYamboG, numq, numthreads)
        integer, intent(in)     :: nx, ny, nz, numBands, numK, numG, numYamboG, numq, numthreads
        real(dp)                :: mem_per_thread, global_mem, total_mem

        !> Global arrays, in bytes
        real(dp)                :: batched_c_nk_bytes, epsm1_unpadded_bytes, epsm1_padded_bytes, &
                                    Vc_screened_bytes, W_bytes, G_vec_cart_bytes, k_cart_bytes, &
                                    yambo_q_bytes

        !> Per thread arrays, in bytes
        real(dp)                :: c_nk_real_store_bytes, c_mp_real_store_bytes, rho_real_bytes, &
                                    rho_G_double_bytes, umklapp_phase_factor_bytes, padded_input_bytes, &
                                    rho_batch_bytes, res_batch_bytes, work_rho_G_bytes, W_k_bytes

        !> Dimensions held as reals, so the products below cannot overflow a default integer
        real(dp)                :: rnx, rny, rnz, rdx, rdy, rdz
        real(dp)                :: rBands, rK, rG, rYamboG, rq

        !> Bytes per element, and the byte -> MB conversion
        real(dp), parameter     :: complex_bytes = 16.0_dp
        real(dp), parameter     :: real_bytes    = 8.0_dp
        real(dp), parameter     :: to_MB         = 1.0d6

        rnx = real(nx, dp)
        rny = real(ny, dp)
        rnz = real(nz, dp)

        !> Density grid is 2n + 1 per direction, matching double_fft_grid in mantel.f90
        rdx = 2.0_dp*rnx + 1.0_dp
        rdy = 2.0_dp*rny + 1.0_dp
        rdz = 2.0_dp*rnz + 1.0_dp

        rBands  = real(numBands, dp)
        rK      = real(numK, dp)
        rG      = real(numG, dp)
        rYamboG = real(numYamboG, dp)
        rq      = real(numq, dp)

        !> Estimate memory usage (in bytes, converted to MB when printed)

        !> GLOBAL ARRAYS
        !> Complex arrays
        batched_c_nk_bytes   = complex_bytes * rnx*rny*rnz * rBands * rK
        epsm1_unpadded_bytes = complex_bytes * rYamboG*rYamboG * rq
        epsm1_padded_bytes   = complex_bytes * rG*rG
        Vc_screened_bytes    = complex_bytes * rG*rG
        W_bytes              = complex_bytes * rBands*rBands * rK
        !> Real arrays
        G_vec_cart_bytes = real_bytes * 3.0_dp * rG
        k_cart_bytes     = real_bytes * 3.0_dp * rK
        yambo_q_bytes    = real_bytes * 3.0_dp * rq

        !> For now we'll neglect those integer arrays since small


        !> PER THREAD ARRAYS
        !> Complex arrays
        c_nk_real_store_bytes      = complex_bytes * rdx*rdy*rdz * rBands
        c_mp_real_store_bytes      = complex_bytes * rdx*rdy*rdz * rBands
        rho_real_bytes             = complex_bytes * rdx*rdy*rdz
        rho_G_double_bytes         = complex_bytes * rdx*rdy*rdz
        umklapp_phase_factor_bytes = complex_bytes * rdx*rdy*rdz
        !> padded_input is allocated per call inside get_real_on_double_grid
        padded_input_bytes         = complex_bytes * rdx*rdy*rdz
        rho_batch_bytes            = complex_bytes * rG * rBands*rBands
        res_batch_bytes            = complex_bytes * rG * rBands*rBands
        work_rho_G_bytes           = complex_bytes * rG
        W_k_bytes                  = complex_bytes * rBands*rBands

        !> Total memory per thread
        mem_per_thread = ( c_nk_real_store_bytes + c_mp_real_store_bytes + rho_real_bytes + &
                           rho_G_double_bytes + umklapp_phase_factor_bytes + padded_input_bytes + &
                           rho_batch_bytes + res_batch_bytes + work_rho_G_bytes + W_k_bytes ) / to_MB

        !> Total global memory
        global_mem = ( batched_c_nk_bytes + epsm1_unpadded_bytes + epsm1_padded_bytes + &
                       Vc_screened_bytes + W_bytes + G_vec_cart_bytes + k_cart_bytes + &
                       yambo_q_bytes ) / to_MB

        !> Total memory (global + per thread * numthreads)
        total_mem = global_mem + mem_per_thread * real(numthreads, dp)

        write(stdout, fmt_divider)
        write(stdout, '(5x,A30,2x,F12.2,A)') 'Global memory:',     global_mem,     ' MB'
        write(stdout, '(5x,A30,2x,F12.2,A)') 'Memory per thread:', mem_per_thread, ' MB'
        write(stdout, '(5x,A30,2x,F12.2,A)') 'Total memory:',      total_mem,      ' MB'
        write(stdout, fmt_divider)
        flush(stdout)

    end subroutine print_memory_estimate
        
end module output