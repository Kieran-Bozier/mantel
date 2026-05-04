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


    !> Obtain and print memory estimates
    subroutine print_memory_estimate(nx, ny, nz, numBands, numK, numG, numYamboG, numq, numthreads)
        integer, intent(in)     :: nx, ny, nz, numBands, numK, numG, numYamboG, numq, numthreads
        real(dp)                :: mem_per_thread, global_mem, total_mem

        !> Global arrays mem
        real(dp)                :: batched_c_nk_mem, epsm1_unpadded_mem, epsm1_padded_mem, &
                                    Vc_screened_mem, W_mem, G_vec_cart_mem, k_cart_mem, &
                                    yambo_q_mem, G_vec_crys_mem, yambo_Gs_mem, gmap_mem, ikp_arr_mem

        !> per thread arrays mem
        integer                 :: double_nx, double_ny, double_nz
        real(dp)                :: c_nk_real_store_mem, c_mp_real_store_mem, rho_real_mem, rho_G_double_mem, &
                                    umklapp_phase_factor_mem, rho_batch_mem, res_batch_mem, W_k_mem

        character(len=24)       :: global_top_name, thread_top_name
        real(dp)                :: global_top_val, thread_top_val
                    
        !> Estimate memory usage (in GB)
        
        !> GLOBAL ARRAYS
        !> Complex arrays
        batched_c_nk_mem = real(nx*ny*nz*numBands*numK, dp) * 16.0d0 / 1.0d9
        epsm1_unpadded_mem = real((numYamboG**2)*numq, dp) * 16.0d0 / 1.0d9
        epsm1_padded_mem = real((numG**2), dp) * 16.0d0 / 1.0d9 
        Vc_screened_mem = real((numG**2), dp) * 16.0d0 / 1.0d9
        W_mem = real((numG**2)*numq, dp) * 16.0d0 / 1.0d9
        !> Real arrays
        G_vec_cart_mem = real(numG*3, dp) * 8.0d0 / 1.0d9
        k_cart_mem = real(numK*3, dp) * 8.0d0 / 1.0d9
        yambo_q_mem = real(numq*3, dp) * 8.0d0 / 1.0d9

        !> For now we'll neglect those integer arrays since small


        !> PER THREAD ARRAYS 
        !> Complex arrays
        double_nx = 2*nx
        double_ny = 2*ny
        double_nz = 2*nz
        c_nk_real_store_mem = real(double_nx*double_ny*double_nz*numBands, dp) * 16.0d0 / 1.0d9
        c_mp_real_store_mem = real(double_nx*double_ny*double_nz*numBands, dp) * 16.0d0 / 1.0d9
        rho_real_mem = real(double_nx*double_ny*double_nz, dp) * 16.0d0 / 1.0d9
        rho_G_double_mem = real((numG**2), dp) * 16.0d0 / 1.0d9
        umklapp_phase_factor_mem = real(numq*numG, dp) * 16.0d0 / 1.0d9
        rho_batch_mem = real(numG * numBands**2 , dp) * 16.0d0 / 1.0d9
        res_batch_mem = real(numG * numBands**2 , dp) * 16.0d0 / 1.0d9
        W_k_mem = real(numBands**2, dp) * 16.0d0 / 1.0d9

        !> Total memory per thread
        mem_per_thread = c_nk_real_store_mem + c_mp_real_store_mem + rho_real_mem + rho_G_double_mem + &
                         umklapp_phase_factor_mem + rho_batch_mem + res_batch_mem + W_k_mem

        !> Total global memory
        global_mem = batched_c_nk_mem + epsm1_unpadded_mem + epsm1_padded_mem + Vc_screened_mem + W_mem + &
                     G_vec_cart_mem + k_cart_mem + yambo_q_mem
        
        !> Total memory (global + per thread * numthreads)
        total_mem = global_mem + mem_per_thread * real(numthreads, dp)

        write(stdout, fmt_divider)
        write(stdout, '(5x,A30,2x,F10.4,A)') 'Global memory:',     global_mem,     ' GB'
        write(stdout, '(5x,A30,2x,F10.4,A)') 'Memory per thread:', mem_per_thread, ' GB'
        write(stdout, '(5x,A30,2x,F10.4,A)') 'Total memory:',      total_mem,      ' GB'
        write(stdout, fmt_divider)
        flush(stdout)

    end subroutine print_memory_estimate
        
end module output