!>      This code converts the Quantum Espresso wfc#.dat files
!>      into the binary format that is later read by mantel.x.

module wfc_io 
    use precision,                  only: dp 
    use array_io,                   only: save_array
    implicit none 
contains
    subroutine read_wfc_dat(filename, mill, evc, igwx, xk, ik)
        !> Reads the raw QE wfc.dat file
        character(len=*), intent(in)           :: filename
        integer, allocatable, intent(out)      :: mill(:,:)
        complex(dp), allocatable, intent(out)  :: evc(:,:)
        integer, intent(out)                   :: igwx
        real(dp), intent(out)                  :: xk(3)
        integer, intent(out)                   :: ik

        integer                                :: npol, nbnd
        integer                                :: file_unit
        integer                                :: ispin, ngw
        logical                                :: gamma_only
        real(dp)                               :: scalef, b_vec(3,3) 
        integer                                :: n

        open(newunit=file_unit, file=trim(filename), status='old', form='unformatted', action='read')
        read(file_unit) ik, xk, ispin, gamma_only, scalef
        read(file_unit) ngw, igwx, npol, nbnd
        read(file_unit) b_vec(1,:), b_vec(2,:), b_vec(3,:)

        if (allocated(mill)) deallocate(mill)
        allocate(mill(3, igwx))
        read(file_unit) mill

        if (allocated(evc)) deallocate(evc)
        allocate(evc(npol*igwx, nbnd))

        do n = 1, nbnd
            read(file_unit) evc(:, n)
        end do

        close(file_unit)

        !> Add some checks on wavefunctions
        if (npol /= 1) then
            print *, "Error: Requires npol=1, but found npol=", npol
            print *, "Error: Non-collinear / SOC wavefunctions are not supported"
            print *, "File: ", trim(filename)
            error stop
        end if

        if (gamma_only) then
            print *, "Error: Requires gamma_only=.false., but found gamma_only=.true."
            print *, "gamma_only=.true. only writes half the G-vectors, which is not supported by mantel.x"
            error stop
        end if 

    end subroutine read_wfc_dat

    
    subroutine write_wfc_bin(filename_out, mill, evc, igwx,  G_max, in_min, in_max)
        !> Writes the data to binary files
        character(len=*), intent(in)           :: filename_out
        integer, intent(in)                    :: mill(:, :)
        complex(dp), intent(in)                :: evc(:, :)
        integer, intent(in)                    :: igwx, G_max, in_min, in_max

        complex(dp), allocatable               :: cube_wfc(:,:,:,:)
        integer                                :: nx, ny, nz
        integer                                :: n_bands_out, in, g_idx, gx, gy, gz, gx_wrap, gy_wrap, gz_wrap 
        real(dp)                               :: frac


        if (in_max > size(evc, 2)) then
            print *, "Error: in_max (", in_max, ") exceeds number of bands in evc (", size(evc, 2), ")"
            error stop
        end if

        if (in_min < 1) then
            print *, "Error: in_min (", in_min, ") must be >= 1"
            error stop
        end if 

        !> band range
        n_bands_out = in_max - in_min + 1

        !> Grid dimensions
        nx = (2 * G_max) +1
        ny = (2 * G_max) +1
        nz = (2 * G_max) +1

        allocate(cube_wfc(nx, ny, nz, n_bands_out))
        cube_wfc = (0.0_dp, 0.0_dp)

        do in = in_min, in_max
            do g_idx = 1, igwx
                gx = mill(1, g_idx)
                gy = mill(2, g_idx)
                gz = mill(3, g_idx)

                !> Only keep G_vectors in the box
                if (abs(gx) <= G_max .and. abs(gy) <= G_max .and. abs(gz) <= G_max) then
                    !> merge is an if/else
                    gx_wrap = merge(gx + 1, nx + gx + 1, gx >= 0)
                    gy_wrap = merge(gy + 1, ny + gy + 1, gy >= 0)
                    gz_wrap = merge(gz + 1, nz + gz + 1, gz >= 0)

                    cube_wfc(gx_wrap, gy_wrap, gz_wrap, in - in_min + 1) = evc(g_idx, in)
                end if
            
            end do
        end do 

        !> Check that enough of the norm is carried over into the truncated wavefunction
        do in = in_min, in_max
            frac = sum(abs(cube_wfc(:,:,:, in - in_min + 1))**2) &
                 / sum(abs(evc(:, in))**2)
            if (frac < 0.999_dp) then
                write(*,'(a,a,a,i0,a,f10.6)') &
                    "WARNING [", trim(filename_out), "] band ", in, &
                    " retained |c|^2 fraction = ", frac
            end if
        end do

        call save_array(trim(filename_out), cube_wfc)
    end subroutine write_wfc_bin

    subroutine print_help()
        print *, "================================================================="
        print *, "                     WFC2BIN CONVERTER                           "
        print *, "================================================================="
        print *, "Usage:"
        print *, "  ./wfc2bin <G_max> <in_min> <in_max> <files...>"
        print *, ""
        print *, "Arguments:"
        print *, "  <G_max>   : Max G-vector index (Grid = 2*G_max + 1)."
        print *, "  <in_min>  : First band index to extract (1-based)."
        print *, "  <in_max>  : Last band index to extract."
        print *, "  <files>   : List of .dat files (use wildcards like *.dat)."
        print *, ""
        print *, "Example:"
        print *, "  ./wfc2bin 12 5 10 ./wfc_dir/*.dat"
        print *, "   (Processes all .dat files, extracts bands 5-10)"
        print *, "================================================================="
    end subroutine print_help

    subroutine G_vectors_arr(G_max, G_vectors)
        !> Generates the G_vectors array
        !>  order is:
        !>  -5, -5, -5
        !>  -5, -5, -4 ...
        integer, intent(in)                :: G_max
        integer, allocatable, intent(out)  :: G_vectors(:, :)
        integer                            :: gx, gy, gz
        integer                            :: index

        allocate(G_vectors(3, (2*G_max +1)**3))

        index = 1
        do gx = -G_max, G_max
            do gy = -G_max, G_max
                do gz = -G_max, G_max
                    G_vectors(:, index) = [gx, gy, gz]
                    index = index + 1
                end do
            end do
        end do 
    
    end subroutine G_vectors_arr

    subroutine print_progress(current, total)
        integer, intent(in) :: current, total
        integer :: percent, i, bar_width
        character(len=20) :: bar
    
        bar_width = 20
        percent = nint((real(current) / real(total)) * 100.0)
        
        ! Create the bar string
        bar = ""
        do i = 1, bar_width
            if (i <= (current * bar_width / total)) then
                bar(i:i) = "#"
            else
                bar(i:i) = "-"
            end if
        end do
    
        ! char(13) is the carriage return (\r)
        write(*, '(a, "[", a, "]", i3, a)', advance='no') char(13), bar, percent, "%"
        
        ! Flush the output buffer so it updates immediately
        flush(6) 
    
        if (current == total) print*, "" ! Move to next line when done
    end subroutine print_progress

end module wfc_io

program wfc2bin
    use wfc_io
    use omp_lib
    implicit none 

    !> variables
    character(len=1024)             :: arg_str
    integer                         :: G_max, in_min, in_max
    integer                         :: num_files, nbnd_out, i

    !> Files
    character(len=1024),allocatable :: file_list(:)

    !> private variable in OMP loops
    character(len=1024)             :: filename_in, filename_out
    integer, allocatable            :: mill(:,:)
    complex(dp), allocatable        :: evc(:,:)
    integer                         :: nbnd_in, igwx, npol
    real(dp)                        :: xk(3)
    integer                         :: ik

    integer                         :: count_done
    !> G_vectors
    integer, allocatable            :: G_vectors(:, :)

    !> cartesian k vectors
    real(dp), allocatable           :: k_cart(:,:)
    logical, allocatable            :: k_filled(:)

    !> Timing
    real(dp)                        :: t_start, t_end, wall_start, wall_end

    !> Argument passing
        if (command_argument_count() < 4) then
        call print_help()
        stop
    end if  

    call get_command_argument(1, arg_str)
    read(arg_str, *) G_max

    call get_command_argument(2, arg_str)
    read(arg_str, *) in_min

    call get_command_argument(3, arg_str)
    read(arg_str, *) in_max

    nbnd_out = in_max - in_min + 1

    num_files = command_argument_count() - 3
    allocate(file_list(num_files))
    do i = 1, num_files
        call get_command_argument(i + 3, file_list(i))
    end do


    call cpu_time(t_start)
    wall_start = omp_get_wtime()
    print *, "Processing", num_files, "files..."

    allocate(k_cart(3, num_files))
    allocate(k_filled(num_files))

    !> Parallel OMP processing
    !$OMP PARALLEL DO DEFAULT(SHARED) &
    !$OMP PRIVATE(i, filename_in, filename_out, mill, evc, igwx, xk, ik) &
    !$OMP SCHEDULE(DYNAMIC, 1)
    do i = 1, num_files
        filename_in = trim(file_list(i))

        call read_wfc_dat(filename_in, mill, evc, igwx, xk, ik)
        write(filename_out, '("ik-", I0, ".bin")') ik
        call write_wfc_bin(filename_out, mill, evc, igwx, G_max, in_min, in_max)

        !> Sanity check on the num files and ik
        if (ik < 1 .or. ik > num_files) then
            print *, "Error: ik value out of range for file ", filename_in, ". ik = ", ik
            stop
        end if

        !> bash lists in lexicographical order, so need to use ik to produce correct ordering
        k_cart(:,ik) = xk
        k_filled(ik) = .true.

        !> progress bar
        !$OMP atomic
        count_done = count_done + 1

        !$OMP critical (update_screen)
            if (mod(count_done, 50) == 0 .or. count_done == num_files) then
                call print_progress(count_done, num_files)
            end if
        !$OMP end critical (update_screen)

    end do 
    !$OMP END PARALLEL DO
    
    !> Check we filled all k_cart entries
    if (.not. all(k_filled)) then
        write(*,'(a)') 'ERROR: not all k-point slots were filled. Missing indices:'
        do i = 1, num_files
          if (.not. k_filled(i)) write(*,'(2x,i0)') i
        end do
        error stop
    end if

    call cpu_time(t_end)
    wall_end = omp_get_wtime()

    !> Write the G_vectors file
    allocate(G_vectors(3, (2*G_max +1)**3))
    call G_vectors_arr(G_max, G_vectors)
    call save_array("G_vectors.bin", G_vectors)

    !> Write the cartesian k vectors
    call save_array("cartesian_k.bin", k_cart)

    print *, "Conversion completed for ", num_files, " files."
    print *, "Total CPU time: ", t_end - t_start, " seconds."
    print *, "Total Wall time: ", wall_end - wall_start, " seconds."

end program wfc2bin