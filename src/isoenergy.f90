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
        print *, "========================================================"
        print *, "                       Isoenergy              "
        print *, "========================================================"
        print *, " Usage:"
        print *, "  isoenergy.x < prefix.mantel.in  "
        print *, ""
        print *, "  Reads in W_iq.bin files along with band_energies.bin"
        print *, "  and q_weights.bin to calculate the energy-averaged "
        print *, "  quantity W(e, e')."
        print *, ""
        print *, " Returns:"
        print *, "  W_ee.dat in format that can be read by IsoME"
        print *, "  mu.dat gives value of mu as function of smearing"
        print *, "========================================================"
        print *   
    end subroutine print_help


end module isoenergy_module



program isoenergy
    use precision,                  only: dp
    use array_io,                   only: load_array, save_array
    use isoenergy_module,           only: linspace
    use read_mantel_in,             only: open_file, check_namelist, read_isoenergy_namelist, read_mantel_namelist
    implicit none

    real(dp),parameter                  ::  pi = 4.0_dp * atan(1.0_dp)
    real(dp),parameter                  ::  Ha_to_eV = 27.211386

    !> Variables from input
    integer                             ::  numE 
    real(dp)                            ::  minE 
    real(dp)                            ::  maxE
    real(dp)                            ::  sigma 
    integer                             ::  in_min 
    integer                             ::  in_max 

    real(dp)                            ::  Ef

    real(dp),allocatable                ::  band_energies(:,:)   ! (nbnd, numK) because of transpose in mantel-xml
    real(dp),allocatable                ::  q_weights(:) 
    integer                             ::  numBands, numK

    !> Energy grid
    real(dp),allocatable                ::  energy_grid(:)

    !> gaussian array
    real(dp),allocatable                ::  gaussian_array(:,:,:)   ! (numE, numBands, numK)
    
    !> gaussian density of states
    real(dp),allocatable                ::  dos(:)

    !> Counters
    integer                             ::  ik, i_n, ie, i_band                      


    !> Load all the variables from .mantel.in and .mantel.nml


    !> Load band energies, q_weights 
    call load_array("band_energies.bin", band_energies)
    call load_array("q_weights.bin", q_weights)

    !> Build energy grid
    allocate(energy_grid(numE))
    call linspace(minE, maxE, numE, energy_grid)

    !> Build Gaussian array
    !> Care needed that in general QE nbnd /= numBands
    numK = size(band_energies, 2)
    numBands = in_max - in_min + 1
    allocate(gaussian_array(numE , numBands, numK))

    do ik = 1, numK
        do i_n = 1, numBands
            !> Need offset to index band_energies
            i_band = in_min + i_n - 1 
            do ie = 1, numE
                gaussian_array(ie, i_n, ik) = (1 / (sigma * sqrt(pi))) &
                        &* exp( - ( energy_grid(ie) - band_energies(i_band, ik) )**2 / (sigma**2)  )
            end do 
        end do 
    end do 


    !> Obtain the DOS 
    allocate( dos(numE) )
    dos=0.0_dp

    do ik = 1, numK
        do i_n = 1, numBands
            dos(:) = dos(:) + gaussian_array(:, i_n, ik)
        end do 
    end do 
    dos = dos / numK

    allocate(W_ee(numE, numE))
    W_ee = 0.0_dp

    !> Loop over q
    do iq = iq_min , iq_max
        call load_array("W_iq"iq".bin", W_iq)
        call load_array("ikp_iq"iq".bin", ikp_arr)
        wq = q_weights(iq) / sum(q_weights)

        do ik = 1, numK 
            A = gaussian_array(:,:,ik)
            B = gaussian_array(:,:,ikp_arr(ik))
            Wk = real(W(:,:,ik))

            call dgemm('N','N', numE, numB, numB, 1.0_dp, A, numE, Wk,  numB, 0.0_dp, T,    numE)
            call dgemm('N','T', numE, numE, numB, wq,     T, numE, B,   numE, 1.0_dp, W_ee_ik, numE)

            W_ee = W_ee + wq*W_ee_ik
        end do 
    end do 

    !> Normalise
    W_ee = W_ee * Ha_to_eV
    allocate(W_ee_norm(numE, numE))

    do ie = 1, numE 
        do je = 1, numE
            W_ee_norm(ie, je) = W_ee(ie, je) / (dos(ie) * dos(je))
        end do
    end do 

    !> Write out the array in the .dat format





end program isoenergy