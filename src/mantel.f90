program mantel

    !> This program calculates the screened Coulomb interaction W_nkmp
    !> in the Bloch basis using FFTs and a padded dielectric matrix.
    
    use precision,              only: dp
    use read_input,             only: read_stdin, read_lattice_vectors, wfc_dir, in_min, in_max, num_electrons
    use array_io,               only: load_array, save_array
    use write_data,             only: write_W
    use precompute,             only: precomputeVol_au3, precomputeReciprocalLattice, &
                                    precomputeCartesianG, precompute_TF_wavevector, &
                                    precompute_zero_G_idx
    use epsm1,                  only: pad_epsm1
    use k_mapping,              only: batch_map_k_via_frac
    use g_mapping,              only: double_g_mapping
    use wfc,                    only: batch_c_nk_structured, get_wfc_dimensions
    use W_nkmp,                 only: initialise_fft_plans, cleanup_fft_plans, &
                                      build_Vc_screened, get_umklapp_phase_factor, W_nkmp_all_n_all_m_opt
    use output,                 only: print_banner, print_clock, print_section_header, print_matrix, print_info_int, &
                                      print_info_real, print_msg, print_int_vec
    use omp_lib
    implicit none

    !>-------------------------------------------------------
    !> Structure
    real(dp)                    ::  lattice_vectors_bohr(3,3)
    real(dp)                    ::  vol_au3
    real(dp)                    ::  recip_lat(3,3)

    !> G vectors
    integer                     ::  numG
    integer, allocatable        ::  G_vec_crys(:,:)            !3, numG
    real(dp), allocatable       ::  G_vec_cart(:,:)            !3, numG
    complex(dp), allocatable    ::  Vc_screened(:,:)           !numG, numG

    !> K points and mapping
    integer                     ::  ik, numK
    integer, allocatable        ::  ik_arr(:)                  !numK
    integer, allocatable        ::  ikp_arr(:)
    character(len=1024)         ::  ikp_filename
    real(dp), allocatable       ::  k_cart(:,:)  
    real(dp), allocatable       ::  k_plus_q_batch(:,:)        !3, numK
    real(dp), allocatable       ::  best_k_vecs(:,:)           !3, numK_in_batch
    logical, allocatable        ::  found_mask(:)              !numK_in_batch
    real(dp)                    ::  tol
    real(dp)                    ::  G_shift_cart(3)            !3,
    complex(dp), allocatable    ::  umklapp_phase_factor(:,:,:)!double_fft_grid(1), double_fft_grid(2),double_fft_grid(3)

    integer                     ::  numBands

    !> G mapping from 3D FFT grid to 1D numG
    integer, allocatable        ::  g_map_i(:)
    integer, allocatable        ::  g_map_j(:)
    integer, allocatable        ::  g_map_k(:)

    !> Wavefunctions
    complex(dp),allocatable     ::  batched_c_nk(:,:,:,:,:)    !wfc_fft_grid(1) , wfc_fft_grid(2), wfc_fft_grid(3), numBands, numK

    !> FFT grids
    integer                     ::  wfc_fft_grid(3)
    integer                     ::  double_fft_grid(3)

    !> OMP workspace
    complex(dp), allocatable    ::  work_rho_G(:)
    complex(dp), allocatable    ::  rho_real(:,:,:)
    complex(dp), allocatable    ::  rho_G_double(:,:,:)
    complex(dp), allocatable    ::  c_nk_real_store(:,:,:,:)
    complex(dp), allocatable    ::  c_mp_real_store(:,:,:,:)
    complex(dp), allocatable    ::  rho_batch(:,:)             ! numG, numBands**2
    complex(dp), allocatable    ::  res_batch(:,:)             ! numG, numBands**2

    !> yambo 
    integer                     ::  iq, num_q
    real(dp)                    ::  q(3)
    real(dp),allocatable        ::  yambo_q(:,:)               !3, num_q
    integer,allocatable         ::  yambo_Gs(:,:)              !3, numYamboG
    complex(dp), allocatable    ::  epsm1_unpadded(:,:,:)
    complex(dp), allocatable    ::  epsm1_padded(:,:)

    !> q=0 special case
    integer                     ::  zero_G_idx
    real(dp)                    ::  q_TF                        !TF wavevector

    !> Output
    complex(dp), allocatable    ::  W_k(:,:)
    complex(dp), allocatable    ::  W(:,:,:)

    !> Timings
    real(dp)                    :: t_cpu_start, t_cpu_end, t_wall_start, t_wall_end
    real(dp)                    :: t_wall_qstart, t_wall_qend

    !> CLI
    integer                     :: nargs
    character(len=16)           :: arg
    !>-------------------------------------------------------

    ! --- help flag ---
    nargs = command_argument_count()
    if (nargs > 0) then
        call get_command_argument(1, arg)
        if (trim(arg) == '-h' .or. trim(arg) == '--help') then
            call print_help()
            stop 0
        end if
    end if

    call cpu_time(t_cpu_start)
    t_wall_start = omp_get_wtime()

    call print_banner()

    call print_section_header("Input and initialization")
    !> Read in wfc_dir, num_electrons, in_min and in_max 
    call read_stdin()

    !> Read lattice vectors
    call read_lattice_vectors(lattice_vectors_bohr)

    !> Load G vectors
    call load_array("G_vectors.bin", G_vec_crys)
    numG = size(G_vec_crys, 2)

    call print_info_int("Num. electrons                     : ",num_electrons)
    call print_info_int("Lower band index (in_min)          : ", in_min)
    call print_info_int("Upper band index (in_max)          : ", in_max)
    numBands = in_max - in_min + 1
    !> in file we use rows as vectors, but internally we use columns
    call print_matrix("Lattice vectors (Bohr)                ", transpose(lattice_vectors_bohr))


    !> Precomputed quantities
    call print_section_header("Precomputations")
    vol_au3     = precomputeVol_au3(lattice_vectors_bohr)
    recip_lat   = precomputeReciprocalLattice(lattice_vectors_bohr)
    G_vec_cart  = precomputeCartesianG(G_vec_crys, recip_lat)
    q_TF       = precompute_TF_wavevector(num_electrons, vol_au3)
    zero_G_idx = precompute_zero_G_idx(G_vec_crys)
    call print_info_real("Volume (au^3)                     : ", vol_au3)
    call print_info_real("Thomas-Fermi q_TF (au^-1)         : ", q_TF)
    call print_matrix("Reciprocal lattice vectors (au^-1)  ", transpose(recip_lat))



    !> Yambo data
    call load_array("yambo_qs.bin", yambo_q)
    call load_array("epsm1_unpadded.bin", epsm1_unpadded)
    call load_array("yambo_Gs.bin", yambo_Gs)
    num_q = size(yambo_q, 2)


    !> load the k-points
    call load_array("cartesian_k.bin", k_cart)
    numK = size(k_cart, 2)
    ik_arr = [(ik, ik=1, numK)]


    !> Build c_nk_batched
    call get_wfc_dimensions(wfc_dir, wfc_fft_grid)
    call batch_c_nk_structured(wfc_dir, numK, wfc_fft_grid, batched_c_nk, numBands)


    !> FFT grid. We initialise inside OMP to get thread safety
    double_fft_grid = (2 * wfc_fft_grid) + 1
    call initialise_fft_plans(double_fft_grid)

    !> Mapping from double FFT grid to numG vector
    allocate( g_map_i(numG) )
    allocate( g_map_j(numG) )
    allocate( g_map_k(numG) )
    call double_g_mapping(G_vec_crys, double_fft_grid, g_map_i, g_map_j, g_map_k)

    call print_section_header("Wavefunctions")
    call print_int_vec("WFC FFT grid                            : ", wfc_fft_grid)
    call print_int_vec("Density FFT grid                        :", double_fft_grid)
    call print_info_int("Number of G-vectors                      : ", numG)
    call print_info_int("Number of k-points                       : ", numK)
    call print_info_int("Number of bands per k-point              : ", in_max - in_min +1)      
    





    !> Pre-allocate arrays
    allocate( ikp_arr(numK) )
    allocate( k_plus_q_batch(3, numK) )
    allocate( best_k_vecs(3, numK) )
    allocate( found_mask(numK) )

    allocate( epsm1_padded(numG, numG) )
    allocate( Vc_screened(numG, numG) )
    allocate( W(in_max - in_min +1, in_max - in_min +1, numK) )



    !> Loop over q points
    call print_section_header("Processing qpoints")
    call print_info_int("Number of q-points               : ", num_q)

    do iq = 1, num_q
        t_wall_qstart = omp_get_wtime()

        q = yambo_q(:, iq)
        
        !> Pad the dielectric matrix d
        call pad_epsm1(epsm1_unpadded(:, :, iq), yambo_Gs, G_vec_crys, epsm1_padded)

        !> Calculate Vc. If iq=1, activates q= 0,0,0 case which is built-in
        call build_Vc_screened(iq, q, G_vec_cart, zero_G_idx, q_TF, epsm1_padded, Vc_screened)

        !> Find the k mapping
        tol = 1.0e-5_dp
        k_plus_q_batch = k_cart + spread( q, 2, numK )
        call batch_map_k_via_frac( k_plus_q_batch, recip_lat, k_cart, best_k_vecs, ikp_arr, found_mask, tol )

        if (.not. all(found_mask)) error stop "Error: Some k+q points could not be mapped to existing k-points."

        !> Save ikp
        write(ikp_filename, '(A,I0,A)') "ikp_iq", iq, ".bin"
        call save_array(ikp_filename, ikp_arr)


        !> Calculate W_nkmp
        !> Use OMP parallelisation over kpoints
        !$OMP PARALLEL DEFAULT(SHARED) &
        !$OMP PRIVATE(ik, G_shift_cart, umklapp_phase_factor, W_k)&
        !$OMP PRIVATE(work_rho_G, rho_real, rho_G_double) &
        !$OMP PRIVATE(c_nk_real_store, c_mp_real_store) &
        !$OMP PRIVATE(rho_batch, res_batch)
        !> private variables need allocating
            allocate( umklapp_phase_factor(double_fft_grid(1), double_fft_grid(2), double_fft_grid(3)) )
            allocate( W_k(in_max - in_min +1, in_max - in_min +1) )
            allocate( work_rho_G(numG))
            allocate( rho_real(double_fft_grid(1), double_fft_grid(2), double_fft_grid(3)) )
            allocate( rho_G_double(double_fft_grid(1), double_fft_grid(2), double_fft_grid(3)) )
            allocate( c_nk_real_store(double_fft_grid(1), double_fft_grid(2), double_fft_grid(3), numBands) )
            allocate( c_mp_real_store(double_fft_grid(1), double_fft_grid(2), double_fft_grid(3), numBands) )
            allocate( rho_batch(numG, numBands**2))
            allocate( res_batch(numG, numBands**2))
            !$OMP DO SCHEDULE(DYNAMIC,1)
            do ik = 1, numK

                !> Umklapp for this kpoint
                G_shift_cart = (k_cart(:,ik) + q) - best_k_vecs(:,ik)
                call get_umklapp_phase_factor(G_shift_cart, lattice_vectors_bohr, double_fft_grid, umklapp_phase_factor)

                !> Calculate W_nkmp for all (n,m) at this kpoint
                call W_nkmp_all_n_all_m_opt(Vc_screened, batched_c_nk(:, :, :, :, ik), batched_c_nk(:, :, :, :, ikp_arr(ik)), &
                                       umklapp_phase_factor, G_vec_crys, double_fft_grid, vol_au3, W_k, &
                                       work_rho_G, rho_real, rho_G_double, &
                                       g_map_i, g_map_j, g_map_k, c_nk_real_store, c_mp_real_store, &
                                       rho_batch, res_batch)

                W(:,:,ik) = W_k
                
            end do
            !$OMP END DO
            deallocate( umklapp_phase_factor )
            deallocate( W_k )
            deallocate( work_rho_G )
            deallocate( rho_real )
            deallocate( rho_G_double )
            deallocate( c_nk_real_store )
            deallocate( c_mp_real_store )
            deallocate( rho_batch )
            deallocate( res_batch )
        !$OMP END PARALLEL

        call write_W(W, iq)
        call print_info_int("Completed iq = ", iq)
        t_wall_qend = omp_get_wtime()
        call print_clock("  Wall time for this qpoint: ", t_wall_qstart, t_wall_qend)
    end do 

    !> write ik
    call save_array("ik.bin", ik_arr)

    !> Cleanup FFT plans
    call cleanup_fft_plans()


    !> Deallocate arrays
    if (allocated(G_vec_crys))        deallocate(G_vec_crys)
    if (allocated(G_vec_cart))        deallocate(G_vec_cart)
    if (allocated(Vc_screened))       deallocate(Vc_screened)

    if (allocated(ik_arr))            deallocate(ik_arr)    
    if (allocated(ikp_arr))           deallocate(ikp_arr)
    if (allocated(k_cart))            deallocate(k_cart)
    if (allocated(k_plus_q_batch))    deallocate(k_plus_q_batch)
    if (allocated(best_k_vecs))       deallocate(best_k_vecs)
    if (allocated(found_mask))        deallocate(found_mask)

    if (allocated(batched_c_nk))    deallocate(batched_c_nk)

    if (allocated(yambo_q))         deallocate(yambo_q)
    if (allocated(yambo_Gs))        deallocate(yambo_Gs)
    if (allocated(epsm1_unpadded))  deallocate(epsm1_unpadded)
    if (allocated(epsm1_padded))    deallocate(epsm1_padded)
    if (allocated(W))               deallocate(W)

    if (allocated(g_map_i))        deallocate(g_map_i)
    if (allocated(g_map_j))        deallocate(g_map_j)
    if (allocated(g_map_k))        deallocate(g_map_k)


    call cpu_time(t_cpu_end)
    t_wall_end = omp_get_wtime()
    call print_section_header("Timing Summary")
    call print_clock("Total CPU time: ", t_cpu_start, t_cpu_end)
    call print_clock("Total Wall time: ", t_wall_start, t_wall_end)



contains

    subroutine print_help()
        write(*,'(A)') 'Usage: mantel.x [-h] < input_file'
        write(*,'(A)') ''
        write(*,'(A)') 'Compute the screened Coulomb interaction W(n,m,k) using Yambo dielectric matrices.'
        write(*,'(A)') ''
        write(*,'(A)') 'Input is read from standard input and must contain two sections:'
        write(*,'(A)') ''
        write(*,'(A)') '  &config'
        write(*,'(A)') '     wfc_dir       = "WFC"   ! directory containing WFC/ik-*.bin files'
        write(*,'(A)') '     num_electrons = <int>    ! number of electrons in the system'
        write(*,'(A)') '     in_min        = <int>    ! lower band index (1-based, inclusive)'
        write(*,'(A)') '     in_max        = <int>    ! upper band index (1-based, inclusive)'
        write(*,'(A)') '  /'
        write(*,'(A)') '  CELL_PARAMETERS bohr|angstrom'
        write(*,'(A)') '    a1_x  a1_y  a1_z'
        write(*,'(A)') '    a2_x  a2_y  a2_z'
        write(*,'(A)') '    a3_x  a3_y  a3_z'
        write(*,'(A)') ''
        write(*,'(A)') 'Required input files (in the working directory):'
        write(*,'(A)') '  G_vectors.bin, cartesian_k.bin, yambo_qs.bin,'
        write(*,'(A)') '  yambo_Gs.bin, epsm1_unpadded.bin, WFC/ik-*.bin'
        write(*,'(A)') ''
        write(*,'(A)') 'Output files:'
        write(*,'(A)') '  W_iq*.bin, ik.bin, ikp_iq*.bin'
        write(*,'(A)') ''
        write(*,'(A)') 'Options:'
        write(*,'(A)') '  -h, --help    Print this message and exit'
    end subroutine print_help

end program mantel