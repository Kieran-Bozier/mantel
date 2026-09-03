module W_nkmp

    !>      This module is repsonsible for computing the W_nkmp
    !>      matrix elements for a single k and q. All possible 
    !>      initial (n) and final (m) bands are considered
    !>

    use iso_fortran_env, only: stderr => error_unit
    use, intrinsic :: iso_c_binding 
    use precision, only: dp
    implicit none
    include 'fftw3.f03'


    type(C_PTR), save :: fft_bwd_plan
    logical, save :: fft_plans_initialized = .false.
    integer, save :: stored_double_dimensions(3) = [0,0,0]


contains
    !>=====================================================================
    subroutine initialise_fft_plans(fft_grid_size)
        !> Initializes the fft plans. Only need backwards fft plan for the 
        !> double density grid
        integer, intent(in) :: fft_grid_size(3)

        
        complex(dp), allocatable :: temp_in(:,:,:), temp_out(:,:,:)

        !>check if already initialized
        if (fft_plans_initialized) call cleanup_fft_plans()

        !>create plan
        allocate(temp_in(fft_grid_size(1), fft_grid_size(2), fft_grid_size(3)))
        allocate(temp_out(fft_grid_size(1), fft_grid_size(2), fft_grid_size(3)))

        !> TO DO: Double check the ordering of fft_grid_size dimensions 
        fft_bwd_plan = fftw_plan_dft_3d(fft_grid_size(1), fft_grid_size(2), fft_grid_size(3), &
                                 temp_in, temp_out, FFTW_BACKWARD, FFTW_MEASURE+FFTW_UNALIGNED)
        deallocate(temp_in, temp_out)
        
        !update states. stored double dimesnions is global
        stored_double_dimensions = fft_grid_size
        fft_plans_initialized = .true.
    end subroutine initialise_fft_plans

    !>=====================================================================
    subroutine cleanup_fft_plans()
        !> Cleans up the fft plans
        if (fft_plans_initialized) then
            call fftw_destroy_plan(fft_bwd_plan)
            fft_plans_initialized = .false.
            stored_double_dimensions = [0,0,0]
        end if
    end subroutine cleanup_fft_plans



    subroutine rho_nkmp_optimised(c_nk_real_double, c_mp_real_double, rho_real, rho_G_double, umklapp_phase_factor, &
                                  G_vec_Crys, double_fft_grid_size, rho_G, wfc_fft_grid, &
                                  g_map_i, g_map_j, g_map_k)
        !> Optimise the rho function by taking in the precomputed wavfunctions on real grid
        !> This reduces the number of FFT calls required
        !>
        !> Be aware that this is NOT a FT of the density/overlap, but rather an inverse FT
        !> because the berkeleyGW code uses the e^{+i G.r} convention
        implicit none
        !---- Arguments ----
        complex(dp), intent(in)         :: c_nk_real_double(:,:,:)
        complex(dp), intent(in)         :: c_mp_real_double(:,:,:)
        complex(dp), intent(inout)      :: rho_real(:,:,:)
        complex(dp), intent(inout)      :: rho_G_double(:,:,:)
        complex(dp), intent(in)         :: umklapp_phase_factor(:,:,:)
        integer, intent(in)             :: G_vec_Crys(:,:)                      ! (3, numG) List of integer Miller indices
        integer, intent(in)             :: double_fft_grid_size(3)
        integer, intent(in)             :: wfc_fft_grid(3)
        complex(dp), intent(out)        :: rho_G(:)                             !returns rho_G
        integer, intent(in)             :: g_map_i(:), g_map_j(:), g_map_k(:)

        !local variables
        integer                         :: idx_x, idx_y, idx_z, numG, n

        !> Optimised by removing the FFT calls inside this function, and moved outside
        ! Compute rho_real = c_nk_double * conjg(c_mp_double)
        rho_real = c_nk_real_double * conjg(c_mp_real_double) * umklapp_phase_factor

        call fftw_execute_dft(fft_bwd_plan, rho_real, rho_G_double)
        rho_G_double = rho_G_double / real(product(double_fft_grid_size), dp)

        numG = size(G_vec_Crys, 2)
        do n = 1, numG
            idx_x = g_map_i(n)
            idx_y = g_map_j(n)
            idx_z = g_map_k(n)

            rho_G(n) = rho_G_double(idx_x, idx_y, idx_z)
        end do
    end subroutine rho_nkmp_optimised

    !>=================================================================
    subroutine get_real_on_double_grid(input_small, small_dims, double_dims, output_real)
        !> Pads and then performs Fourier transform to real space
        complex(dp), intent(in)         ::  input_small(:,:,:)
        integer, intent(in)             ::  small_dims(3), double_dims(3)
        complex(dp), intent(out)        ::  output_real(:,:,:)

        complex(dp), allocatable                     ::  padded_input(:,:,:)
        integer                         ::  i,j,k, i_out, j_out, k_out 
        integer                         ::  midpoint(3)
        
        allocate(padded_input(double_dims(1), double_dims(2), double_dims(3)))
        padded_input = (0.0_dp, 0.0_dp)
        midpoint = (small_dims/2) + 1

        !Pad the array - or rather embed elements of array into new larger zero array
        !Indexing is s.t. +ve frequencies have +ve index and -ve frequencies have -ve index
        do k= 1, small_dims(3)
            do j= 1, small_dims(2)
                do i= 1, small_dims(1)
                    if (i <= midpoint(1)) then
                        i_out = i
                    else    
                        i_out = double_dims(1) - (small_dims(1) - i)
                    end if
                    
                    if (j <= midpoint(2)) then
                        j_out = j
                    else
                        j_out = double_dims(2) - (small_dims(2) - j)
                    end if
                    
                    if (k <= midpoint(3)) then
                        k_out = k
                    else
                        k_out = double_dims(3) - (small_dims(3) - k)
                    end if
                    
                    padded_input(i_out, j_out, k_out) = input_small(i, j, k) 
                end do 
            end do
        end do 

        !> Perform inverse FFT to get real space representation
        call fftw_execute_dft(fft_bwd_plan, padded_input, output_real)
    
    end subroutine get_real_on_double_grid

    !>=================================================================
    subroutine truncate_to_small_grid(rho_large, double_dims, small_dims, rho_small)
        !> Truncates by copying the "corners" (low freq) directly.
        !> Preserves Standard FFT order (G=0 at index 1).
        implicit none
        complex(dp), intent(in)  :: rho_large(:,:,:)
        integer, intent(in)      :: double_dims(3), small_dims(3)
        complex(dp), intent(out) :: rho_small(:,:,:)

        integer :: i, j, k
        integer :: i_in, j_in, k_in
        integer :: mid(3)

        ! The highest positive frequency index for the SMALL grid
        ! e.g. if N=7, mid=4. Indices 1,2,3,4 are 0,1,2,3.
        mid = small_dims / 2 + 1

        do k = 1, small_dims(3)
            do j = 1, small_dims(2)
                do i = 1, small_dims(1)
                    
                    if (i <= mid(1)) then
                        ! Positive Freqs (0, 1, 2...): Copy directly
                        i_in = i 
                    else
                        ! Negative Freqs (-1, -2...): Wrap from end of Large
                        i_in = double_dims(1) - (small_dims(1) - i)
                    end if

                    if (j <= mid(2)) then
                        j_in = j
                    else
                        j_in = double_dims(2) - (small_dims(2) - j)
                    end if

                    if (k <= mid(3)) then
                        k_in = k
                    else
                        k_in = double_dims(3) - (small_dims(3) - k)
                    end if

                    ! Copy value
                    rho_small(i,j,k) = rho_large(i_in, j_in, k_in)
                    
                end do
            end do
        end do
    end subroutine truncate_to_small_grid


    !>=================================================================
    subroutine get_umklapp_phase_factor(G_shift_cart, lattice_vectors_bohr, double_fft_grid_size, phase_factor)
        !> Computes the umklapp phase factor on the double grid
        real(dp), intent(in)      :: G_shift_cart(3)
        real(dp), intent(in)      :: lattice_vectors_bohr(3,3)
        integer, intent(in)       :: double_fft_grid_size(3)
        complex(dp), intent(out)  :: phase_factor(:,:,:)

        integer                    :: i,j,k
        real(dp) :: G_dot_lat(3) ! The projection of Lattice vectors onto G_shift
        real(dp) :: exponent
        
        !> Debug - try setting to transpose
        G_dot_lat = matmul( transpose(lattice_vectors_bohr), G_shift_cart)
        
        ! 2. LOOP
        do k = 1, double_fft_grid_size(3)
           do j = 1, double_fft_grid_size(2)
              do i = 1, double_fft_grid_size(1)
                 
                 ! Now the exponent is just a weighted sum of the pre-calculated dots
                 exponent = (real(i-1,dp) / double_fft_grid_size(1)) * G_dot_lat(1) + &
                            (real(j-1,dp) / double_fft_grid_size(2)) * G_dot_lat(2) + &
                            (real(k-1,dp) / double_fft_grid_size(3)) * G_dot_lat(3)
                 
                 phase_factor(i,j,k) = exp( (0.0_dp, 1.0_dp) * exponent)
              end do
           end do
        end do
    end subroutine get_umklapp_phase_factor

    !> ===========================================================
    subroutine W_nkmp_all_n_all_m_opt(Vc_screened, c_nk_all_n, c_mp_all_m, umklapp_phase_factor, G_vec_crys,&
        double_fft_grid_size, cell_volume, W_k, &
        rho_G, rho_real, rho_G_double, &
        g_map_i, g_map_j, g_map_k, c_nk_real_store, c_mp_real_store,&
        rho_batch, res_batch)
        !> Optimised version, which performs FFT outside the n,m loops. Instead, it does the FFT 
        !> first, and then indexes the result
    
        !>-------  Args --------
        !> Main arrays
        complex(dp), intent(in)            ::   Vc_screened(:,:)
        complex(dp), intent(in)            ::   c_nk_all_n(:,:,:,:)
        complex(dp), intent(in)            ::   c_mp_all_m(:,:,:,:)
        complex(dp), intent(in)            ::   umklapp_phase_factor(:,:,:)
        complex(dp), intent(out)           ::   W_k(:,:)

        !> Other parameters 
        integer, intent(in)                ::   G_vec_crys(:,:)
        integer, intent(in)                ::   double_fft_grid_size(3)
        real(dp), intent(in)               ::   cell_volume
        complex(dp), intent(inout)         ::   rho_G(:), rho_real(:,:,:), rho_G_double(:,:,:)
        integer, intent(in)                ::   g_map_i(:), g_map_j(:), g_map_k(:)

        !> Additional. Arrays to store precomputed real space wfc
        complex(dp), intent(inout)         ::    c_nk_real_store(:,:,:,:)
        complex(dp), intent(inout)         ::    c_mp_real_store(:,:,:,:)
        integer                            ::    wfc_grid_size(3)   
        
        !> Batching rho so that can use zgemm
        complex(dp), intent(inout)         ::     rho_batch(:,:)        ! (numG, numBands**2)
        complex(dp), intent(inout)         ::     res_batch(:,:)
        integer                            ::     col_idx

        !> Calculating oscillators
        integer                             ::   i_n, i_m
        integer                             ::   numG, num_n, num_m

        !> BLAS variables
        integer                             ::   M, N, K, LDA, LDB, LDC
        complex(dp)                         ::   ALPHA, BETA
        !external                            :: zgemv
        !complex(dp), external               :: zdotu
        external                            :: zgemm
        complex(dp), external               ::   zdotc




        wfc_grid_size = shape(c_nk_all_n(:, :, :, 1))
        numG = size(Vc_screened, 1)
        num_n = size(c_nk_all_n, 4)
        num_m = size(c_mp_all_m, 4)

        !> allocate memory. Consider moving outside for better optimisation later
        !allocate(c_nk_real_store(double_fft_grid_size(1), double_fft_grid_size(2), double_fft_grid_size(3), num_n))
        !allocate(c_mp_real_store(double_fft_grid_size(1), double_fft_grid_size(2), double_fft_grid_size(3), num_m))

        !> Precalculate wavefunctions on real double grid
        !> First c_nk
        do i_n = 1, num_n
            call get_real_on_double_grid(c_nk_all_n(:, :, :, i_n), wfc_grid_size, double_fft_grid_size, &
                                        c_nk_real_store(:, :, :, i_n))
        end do
        !> Then c_mp
        do i_m = 1, num_m
            call get_real_on_double_grid(c_mp_all_m(:, :, :, i_m), wfc_grid_size, double_fft_grid_size, &
                                        c_mp_real_store(:, :, :, i_m))
        end do

        

        !> Loop over all n,m bands
        col_idx = 0
        do i_m = 1, num_m
            do i_n = 1, num_n
                col_idx = col_idx + 1

                !> Calculate oscillator
                call rho_nkmp_optimised( c_nk_real_store(:, :, :, i_n), c_mp_real_store(:, :, :, i_m), &
                                rho_real, rho_G_double, umklapp_phase_factor, &
                                G_vec_crys, double_fft_grid_size, rho_G, wfc_grid_size, &
                                g_map_i, g_map_j, g_map_k)
                
                !> Use conjugate here, and then zdotc later will flip back
                rho_batch(:, col_idx) = conjg(rho_G)
            end do
        end do

        !> Now perform the matrix vector multiplies for each column
        M = numG
        N = num_n * num_m
        K = numG
        LDA = numG
        LDB = numG 
        LDC = numG
        ALPHA = (1.0_dp, 0.0_dp)
        BETA  = (0.0_dp, 0.0_dp)

        call zgemm('N', 'N', M, N, K, ALPHA, Vc_screened, LDA, rho_batch, LDB, BETA, res_batch, LDC)

        col_idx = 0
        do i_m = 1, num_m
            do i_n = 1, num_n
                col_idx = col_idx + 1
                W_k(i_n, i_m) = zdotc(numG, rho_batch(:, col_idx), 1, res_batch(:, col_idx), 1) * (1.0_dp / cell_volume)
            end do
        end do 

    end subroutine W_nkmp_all_n_all_m_opt


    !> ==========================================================
    subroutine build_Vc_screened(iq, q, cartesian_G_vectors, zero_G_idx, q_TF, epsm1_padded, Vc_screened)
        !> Calculates Vc_screened(G, G') = 4pi / |q+G||q+G'| * epsm1_padded^-1(G, G')
        !> If iq=1, sets head to TF result and wings to 0
        !> Called in the main script
        integer, intent(in)       :: iq                         !if iq==1, activates q=0 case
        integer, intent(in)       :: zero_G_idx                 !index of G=0 vector
        real(dp), intent(in)      :: cartesian_G_vectors(:,:)   !(3, N_G_vectors)
        real(dp), intent(in)      :: q(3), q_TF
        complex(dp), intent(in)   :: epsm1_padded(:,:)          !(N_G , N_G)
        complex(dp), intent(out)  :: Vc_screened(:,:)           !(N_G , N_G)

        integer                   :: numG, i, j
        real(dp)                  :: q_plus_G(3)
        real(dp)                  :: norm_q_plus_G
        real(dp), allocatable     :: inv_qG(:)

        real(dp), parameter      :: four_pi = 4.0_dp * 3.14159265358979323846_dp
        real(dp), parameter      :: epsilon = 1.0e-6_dp 

        numG = size(cartesian_G_vectors, 2)
        allocate(inv_qG(numG))

    


        !> Calculates inverse norms 1 / |q+G|
        do i = 1, numG
            q_plus_G = q + cartesian_G_vectors(:, i)
            norm_q_plus_G = sqrt( dot_product(q_plus_G, q_plus_G) )
            if (norm_q_plus_G > epsilon ) then
                inv_qG(i) = 1.0_dp / norm_q_plus_G
            else
                !> If this happens when not at G=0, then something is likely wrong
                if (i /= zero_G_idx) then
                    write(stderr, *) &
                    "Warning: |q+G| is very small (", norm_q_plus_G,&
                         ") for G index ", i, ". This may indicate an issue with the input data."
                end if
                
                inv_qG(i) = 0.0_dp   ! Handle the singularity case
            end if
        end do

        !$OMP PARALLEL DO DEFAULT(shared) PRIVATE(i,j)
        do j = 1, numG
            do i = 1, numG
                Vc_screened(i,j) = four_pi * inv_qG(i) * inv_qG(j) * epsm1_padded(i,j)
            end do
        end do
        !$OMP END PARALLEL DO

        !> Handle the q=0 case
        if (dot_product(q,q) < epsilon) then  

            !> Ensure q_TF is not zero to avoid division by zero
            if (q_TF <= epsilon) then
                write(stderr, *) &
                    "Error: Thomas-Fermi wavevector q_TF is too small (", q_TF, "). Cannot compute head of Vc_screened."
                    write(stderr, *) "Please check the num electrons if using qtf_method = 'electrons'"                
                    error stop 1
            end if
            
            if (zero_G_idx >= 1 .and. zero_G_idx <= numG) then
                ! Wings -> 0
                Vc_screened(zero_G_idx, :) = (0.0_dp, 0.0_dp)
                Vc_screened(:, zero_G_idx) = (0.0_dp, 0.0_dp)
                
                ! Head -> TF Screening: 4pi / q_TF^2
                Vc_screened(zero_G_idx, zero_G_idx) = &
                    cmplx(four_pi / (q_TF**2), 0.0_dp, dp)
            else
                 write(stderr, *) &
                 "Error: zero_G_idx (", zero_G_idx, ") is out of bounds for Vc_screened with numG = ", numG
                 error stop 1
            end if
        end if

        deallocate(inv_qG)
    end subroutine build_Vc_screened


end module W_nkmp 
