module isoenergy_module
    use precision,                  only : dp
    implicit none
contains
    subroutine linspace(min, max, num, arr)
        !> Fortran version of linspace
        real(dp), intent(in)        :: min
        real(dp), intent(in)        :: max
        integer, intent(in)         :: num
        real(dp), intent(out)       :: arr(num)
        
        real(dp)                    :: delta
        integer                     :: i

        if (num <= 0) then
            print *, "Number of elements must be positive"
            error stop
        end if

        if (min > max) then
            print *, "min value greater than max value"
            error stop
        end if

        if (num < 2) then
            print *, "Less than two elements - not enough points for array"
            error stop
        end if 

        !> spacing. If N elements there are N-1 spaces
        delta = ((max) - (min)) / (num - 1)

        do i = 1, num
            arr(i) = min + (i-1)*delta
        end do
    end subroutine linspace


    subroutine print_help()
        print *, "======================================================"
        print *, "                     Isoenergy              "
        print *, "======================================================"
        print *, "Usage:"
        print *, "  ./isoenergy <numE> <minE> <maxE> <sigma>"
        print *, ""
        print *, "Arguments: "
        print *, "  <num E>     :   Number of points in energy range"
        print *, "  <minE>      :   Minimum energy (eV)"
        print *, "  <maxE>      :   Maximum energy (eV)"
        print *, "  <sigma>     :   Gaussian smearing width (eV)"
        print *, "======================================================"
        print *   
    end subroutine print_help

    subroutine gauss_scalar(x, sigma, result)
        !> Returns the value of the Gaussian function for scalar x
        real(dp), intent(in)        :: x
        real(dp), intent(in)        :: sigma
        real(dp), intent(out)       :: result

        real(dp)                    :: norm
        real(dp), parameter         :: pi = 3.14159265358979323846_dp

        !> Use QE convention
        norm = (1.0_dp / (sigma * sqrt(pi)))
        result = norm * exp( - (x**2) / (sigma**2) )
    end subroutine gauss_scalar

end module isoenergy_module



program isoenergy
    use precision,                  only: dp
    use array_io,                   only: load_array, save_array
    use isoenergy_module,           only: linspace
    implicit none

    !> Input
    character(len=1024)             ::      arg_str
    integer                         ::      numE
    real(dp)                        ::      minE, maxE
    real(dp)                        ::      sigma
    real(dp), allocatable           ::      energy(:)


    real(dp), allocatable           ::      band_energies(:,:)         
    complex(dp), allocatable        ::      W_nkmp(:,:,:)
    complex(dp), allocatable        ::      W_ee(:,:)
    complex(dp)                     ::      W_term  
    
    integer, allocatable            ::      ikp_arr(:)
    integer                         ::      numK    

    real(dp), allocatable           ::      q_weights(:)
    integer                         ::      iq, num_q

    character(len=256)              ::      W_filename
    integer                         ::      ik, ikp, i_n, i_m, ie, je

    integer                         ::      in_min, in_max, im_min, im_max, i, j
    real(dp)                        ::      delta_nk, delta_mp
    real(dp), allocatable           ::      g_nk_vec(:), g_mp_vec(:)


    !> Read input arguments
    !> Inputs should be: sigma, energy min, energy max, numE
    if (command_argument_count() < 6) then
        call print_help()
        stop
    end if

    call get_command_argument(1, arg_str)
    read(arg_str, *) numE

    call get_command_argument(2, arg_str)
    read(arg_str, *) minE 

    call get_command_argument(3, arg_str)
    read(arg_str, *) maxE 

    call get_command_argument(4, arg_str)
    read(arg_str, *) sigma

    call get_command_argument(5, arg_str)
    read(arg_str, *) in_min

    call get_command_argument(6, arg_str)
    read(arg_str, *) in_max

    !> For now, just set equal to one another
    im_min = in_min
    im_max = in_max

    !> energy
    call linspace(minE, maxE, numE, energy)


    !> Read in the band energies 
    call load_array("band_energies.bin", band_energies)
    numK = size(band_energies, 2)
    call load_array("q_weights.bin", q_weights)
    num_q = size(q_weights)


    allocate(W_ee(numE, numE))
    W_ee = cmplx(0.0_dp, 0.0_dp, kind=dp)
    W_term = cmplx(0.0_dp, 0.0_dp, kind=dp)


    do iq = 1, num_q  
        write(W_filename, '(A,I0,A)') "W_", iq, ".bin"      
        call load_array(W_filename, W_nkmp)


        !> Calculate the gaussian for energy vector first, then do weighting
        !$OMP PARALLEL DO DEFAULT(SHARED) &
        !$OMP PRIVATE(i, j, ik, ikp, i_n, i_m, ie, je)&
        !$OMP PRIVATE(delta_nk, delta_mp, g_nk_vec, g_mp_vec) &
        !$OMP PRIVATE(W_term)
        !$OMP REDUCTION(+: W_ee)
        do ik = 1, numK
            ikp = ikp_arr(ik)

            !> gaussian vectors
            do i_n = in_min, in_max
                do ie = 1, numE
                    delta_nk = band_energies(i_n, ik) - energy(ie)
                    call gauss_scalar(delta_nk, sigma, g_nk_vec(ie))
                end do
            end do

            do i_m = im_min, im_max 
                do je = 1, numE
                    delta_mp = band_energies(i_m, ikp) - energy(je)
                    call gauss_scalar(delta_mp, sigma, g_mp_vec(je))
                end do
            end do

            !> Now obtain weighted W_ee
            do i_n = in_min, in_max
                do i_m = im_min, im_max 

                    W_term = W_nkmp(i_n, i_m, ik) * q_weights(iq)
                    do ie = 1, numE
                        do je = 1, numE
                            W_ee(je,ie) = W_ee(je,ie) +  (W_term * g_nk_vec(ie) * g_mp_vec(je))
                        end do
                    end do 
                
                end do           !<- final band
            end do             !<- initial band
        
        end do
        !$OMP END PARALLEL DO
    end do

end program isoenergy