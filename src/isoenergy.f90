module isoenergy_module
    use precision,                  only : dp, ic
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

    subroutine write_W_ee_dat(filename, energy_grid, W_ee, sigma)
        !> Writes W(e,e') in the gnuplot block format that IsoME reads.
        !>
        !> Each row is:   e    e'    W(e,e')
        !> with a blank line between blocks of constant e, which is what
        !> tells gnuplot the data is a surface rather than a single curve.
        !>
        !> W_ee is expected to be already normalised by dos(e)*dos(e').
        !> Energies are relative to the Fermi level, so the header records
        !> the Fermi energy as zero.

        character(len=*), intent(in)    :: filename
        real(dp), intent(in)            :: energy_grid(:)
        real(dp), intent(in)            :: W_ee(:,:)
        real(dp), intent(in)            :: sigma

        integer                         :: out_unit, ios
        integer                         :: numE, ie, je
        character(len=256)              :: msg

        numE = size(energy_grid)

        !> The grid has to match both sides of the matrix
        if (size(W_ee, 1) /= numE .or. size(W_ee, 2) /= numE) then
            print *, "Error: W_ee is ", size(W_ee, 1), "x", size(W_ee, 2), &
                     " but the energy grid has ", numE, " points"
            error stop "Fatal error writing W_ee.dat"
        end if

        open(newunit=out_unit, file=trim(filename), status='replace', &
             action='write', iostat=ios, iomsg=msg)
        if (ios /= 0) then
            print *, "Error: could not open ", trim(filename)
            print *, "System message: ", trim(msg)
            error stop "Fatal error writing W_ee.dat"
        end if

        write(out_unit, '("# Fermi energy [eV] = 0.  Smearing width (sigma) [eV] = ", F0.6)') sigma
        write(out_unit, '("# energy (e) [eV]      energy (e'') [eV]       W(e,e'') [eV]")')

        do ie = 1, numE
            !> Blank line between blocks, but not before the first one
            if (ie > 1) write(out_unit, '(A)') ""

            do je = 1, numE
                write(out_unit, '(ES17.10E2, 5X, ES17.10E2, 5X, ES17.10E2)') &
                        energy_grid(ie), energy_grid(je), W_ee(ie, je)
            end do
        end do

        close(out_unit)

    end subroutine write_W_ee_dat



end module isoenergy_module



program isoenergy
    use precision,                  only: dp, ic
    use array_io,                   only: load_array, save_array
    use isoenergy_module,           only: linspace, write_W_ee_dat
    use read_mantel_in,             only: open_file, read_mantel_namelist, read_isoenergy_namelist, &
                                            in_min, in_max, iq_min, iq_max, numE, minE, maxE, sigma
    use read_mantel_nml,            only: open_nml, read_system_namelist, scf_fermi
    implicit none

    real(dp),parameter                  ::  pi = 4.0_dp * atan(1.0_dp)
    real(dp),parameter                  ::  Ha_to_eV = 27.211386_dp

    real(dp),allocatable                ::  band_energies(:,:)   ! (nbnd, numK) because of transpose in mantel-xml
    real(dp),allocatable                ::  q_weights(:) 
    real(dp)                            ::  wq
    integer                             ::  numBands, numK

    !> Energy grid
    real(dp),allocatable                ::  energy_grid(:)

    !> gaussian array
    real(dp),allocatable                ::  gaussian_array(:,:,:)   ! (numE, numBands, numK)
    
    !> gaussian density of states
    real(dp),allocatable                ::  dos(:)

    !> Counters
    integer                             ::  ik, i_n, i_band, ie, je, iq
    
    integer                             ::  mantel_in_unit, mantel_nml_unit

    character(len=20)                   ::  filename
    integer(ic),allocatable             ::  ikp_arr(:)

    complex(dp),allocatable             ::  W_iq(:,:,:)
    real(dp),allocatable                ::  Wk(:,:), W_ee(:,:), W_ee_norm(:,:), A(:,:), B(:,:), T(:,:)
    real(dp),parameter                  ::  tolerance=1.0e-5_dp


    !> Load all the variables from .mantel.in and .mantel.nml
    call open_file(mantel_in_unit, "")
    call read_mantel_namelist(mantel_in_unit)
    call read_isoenergy_namelist(mantel_in_unit)

    call open_nml(mantel_nml_unit)
    call read_system_namelist(mantel_nml_unit)
    close(mantel_nml_unit)


    !> Load band energies, q_weights 
    call load_array("band_energies.bin", band_energies)
    call load_array("q_weights.bin", q_weights)

    if (size(band_energies,1) < in_max) then
        print *, "Error: in_max is out of bounds of band_energies"
        error stop 
    end if

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
                        &* exp( - ( energy_grid(ie) - ( band_energies(i_band, ik) - scf_fermi) )**2 / (sigma**2)  )
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
    if (iq_max == -1) iq_max = size(q_weights)
    !> check
    if (iq_max > size(q_weights)) then
        print *, "Error: iq_max (", iq_max, ") exceeds the number of q points (", size(q_weights), ")"
        error stop
    end if

    if (iq_min < 1 .or. iq_min > iq_max) then
        print *, "Error: iq_min (", iq_min, ") must lie between 1 and iq_max (", iq_max, ")"
        error stop
    end if


    allocate(T(numE, numBands))
    allocate(A(numE, numBands))
    allocate(B(numE, numBands))
    allocate(Wk(numBands, numBands))
   
    do iq = iq_min , iq_max
        write(filename, '("W_iq", I0, ".bin")') iq
        call load_array(filename, W_iq)

        !> Check
        if (size(W_iq, 1) /= numBands) then
            print *, "Error: mismatch in the dimensions of W_iq and the number of bands"
            error stop
        end if 

        if (size(W_iq, 3) /= numK) then 
            print *, "Error: mismatch in band_energies and W dimensions (num kpoints)"
            error stop 
        end if 

       

        write(filename, '("ikp_iq", I0, ".bin")') iq
        call load_array(filename, ikp_arr)
        wq = q_weights(iq) / sum(q_weights)

        if (size(ikp_arr) /= numK) then 
            print *, "Error: mismatch in band_energies and ikp dimensions (num kpoints)"
            error stop 
        end if 

        do ik = 1, numK 
            !> Input check            
            if (ikp_arr(ik) < 1 .or. ikp_arr(ik) > numK) then
                print *, "Error: ikp_arr index out of range at ik =", ik, ", value =", ikp_arr(ik)
                error stop
            end if

            A = gaussian_array(:,:,ik)
            B = gaussian_array(:,:,ikp_arr(ik))
            Wk = real(W_iq(:,:,ik))

            call dgemm('N','N', numE, numBands, numBands, 1.0_dp, A, numE, Wk,  numBands, 0.0_dp, T, numE)
            !> beta being one means acculumates to W_ee
            call dgemm('N','T', numE, numE, numBands, wq, T, numE, B, numE, 1.0_dp, W_ee, numE)
            
        end do 
    end do 

    !> Normalise
    W_ee = W_ee * Ha_to_eV / numK
    allocate(W_ee_norm(numE, numE))

    do ie = 1, numE 
        do je = 1, numE
            if (dos(ie) * dos(je) < tolerance) then
                W_ee_norm(ie, je) = 0.0_dp
            else 
                W_ee_norm(ie, je) = W_ee(ie, je) / (dos(ie) * dos(je))
            end if 
        end do
    end do 

    !> Write out the array in the .dat format
    call write_W_ee_dat("W_ee.dat", energy_grid, W_ee_norm, sigma)

end program isoenergy