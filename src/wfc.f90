module wfc

    !>      This module is responsible for handling the loading of wavefunctions

    use precision, only: dp
    use array_io , only: load_array
    implicit none

    contains 
    subroutine batch_c_nk_structured(wfc_dir, &
                                    numK, &
                                    grid_dims, &
                                    batched_c_nk, &
                                    numBands)
        !> Loads the (grid_x, grid_y, grid_z, all_bands) wavefunctions
        !> Into the (grid_x, grid_y, grid_z, numBands, numK) batched_c_nk array
        !>
        !> Modified so in_min and in_max are now not used. The indexing will be 
        !> handled by the wfc2bin converter to avoid loading unnecessary bands.
        implicit none
        character(len=*), intent(in)          :: wfc_dir
        integer, intent(in)                   :: numK
        integer, intent(in)                   :: grid_dims(3)
        complex(dp), allocatable, intent(out) :: batched_c_nk(:,:,:,:,:)
        integer, intent(in)                   :: numBands


        !> Local variables
        integer                               :: ik
        complex(dp), allocatable              :: buffer(:,:,:,:)
        integer                               :: nx, ny, nz
        character(len=100)                    :: filename
        character(len=200)                    :: full_path
        integer                               :: expected_bands

        nx = grid_dims(1)
        ny = grid_dims(2)
        nz = grid_dims(3)
        
        !> If in_min/in_max not provided, set to full range
        ! local_min = in_min
        ! local_max = in_max
        ! expected_bands = local_max - local_min + 1
        ! if (expected_bands < 1) error stop "Invalid band range requested."
        expected_bands = numBands

        !> Allocate batched_c_nk. Might be very large!
        allocate(batched_c_nk(nx, ny, nz, expected_bands, numK))

        !> Check expected bands is within range of stored bands
        !> Load first file to check number of bands
        write(filename, '("ik-", I0, ".bin")') 1
        full_path = trim(wfc_dir) // '/' // trim(filename)
        call load_array(full_path, buffer)
        if (size(buffer, 4) /= numBands) then
            print *, "Error: Requested number of bands doesn't match number stored in wfc.bin file. Check&
                        &that wfc2bin was run with correct band range."
            print *, "Requested num band: ", numBands
            print *, "Available bands: ", size(buffer, 4)
            error stop
        end if


        !> use dynamic scheduling to balance load
        !$OMP PARALLEL DO DEFAULT(SHARED) &
        !$OMP PRIVATE(ik, filename, full_path, buffer) &
        !$OMP SCHEDULE(DYNAMIC, 1)                              
        do ik = 1, numK
            
            !> path 
            write(filename, '("ik-", I0, ".bin")') ik
            full_path = trim(wfc_dir) // '/' // trim(filename) 
            
            !> load nx, ny, nz, total_bands wavefunctions
            call load_array(full_path, buffer)

            !> extract in_min:in_max bands and store in batched_c_nk
            !>batched_c_nk(:,:,:,:,ik) = buffer(:,:,:,in_min:in_max)
            batched_c_nk(:,:,:,:,ik) = buffer(:,:,:,:)

            !> cleanup
            if (allocated(buffer)) deallocate(buffer)
        end do

    end subroutine batch_c_nk_structured


    subroutine get_wfc_dimensions(wfc_dir, dims)
        use iso_fortran_env, only: int32
        implicit none
        character(len=*), intent(in)   :: wfc_dir
        character(len=1024)            :: filename
        character(len=2048)            :: full_path
        integer, intent(out)          :: dims(3)
        
        integer                       :: file_id, rank
        integer(int32)                :: rank_32, type_32
        integer(int32), allocatable   :: dims_32(:)

        write(filename, '("ik-", I0, ".bin")') 1
        full_path = trim(wfc_dir) // '/' // trim(filename)
        open(newunit=file_id, file=full_path, status='old', access='stream', action='read')

        ! 1. Read Rank
        read(file_id) rank_32
        rank = int(rank_32)

        ! 2. Read Type ID
        read(file_id) type_32

        ! 3. Read Dimensions
        allocate(dims_32(rank))
        read(file_id) dims_32

        ! 4. Check and assign
        if (rank < 3) error stop "Error: Wavefunction rank is less than 3!"
        
        dims(1) = int(dims_32(1))
        dims(2) = int(dims_32(2))
        dims(3) = int(dims_32(3))

        deallocate(dims_32)
        close(file_id)
    end subroutine get_wfc_dimensions


end module wfc 