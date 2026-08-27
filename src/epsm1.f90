module epsm1

    !>          This module is responsible for handling the padding
    !>          of the inverse dielectric matrix to match the dimensions
    !>          of the wavefunctions


    use precision,           only: dp
    implicit none

contains    
    
    subroutine build_lookup_table(G_vec_crys, lookup_array)
    !> Builds a lookup array. The (h,k,l) entry of the array contains the
    !> index of the G-vector with crystal coordinates (h,k,l) in G_vec_crys
    implicit none 
    integer, intent(in)               :: G_vec_crys(:, :)  !3, numG
    integer                           :: h, k, l
    integer                           :: numG
    integer                           :: i
    integer                           :: max_h, max_k, max_l
    integer                           :: min_h, min_k, min_l
    integer, allocatable, intent(out) :: lookup_array(:,:,:)

    numG = size(G_vec_crys, 2)
    
    max_h = maxval(G_vec_crys(1, :))
    max_k = maxval(G_vec_crys(2, :))
    max_l = maxval(G_vec_crys(3, :))
    min_h = minval(G_vec_crys(1, :))
    min_k = minval(G_vec_crys(2, :))
    min_l = minval(G_vec_crys(3, :))

    allocate(lookup_array(min_h:max_h, min_k:max_k, min_l:max_l))
    lookup_array = 0

    do i = 1, numG
        h = G_vec_crys(1, i)
        k = G_vec_crys(2, i)
        l = G_vec_crys(3, i)
        lookup_array(h, k, l) = i
    end do

    !>Table should be built - check if any entries are still zero (indicating missing G-vectors)
    !>Sa
    do h = min_h, max_h
        do k = min_k, max_k
            do l = min_l, max_l
                if (lookup_array(h, k, l) == 0) then
                    print *, "Warning: Missing G-vector for (", h, ",", k, ",", l, ")"
                end if
            end do
        end do
    end do

    end subroutine build_lookup_table

    subroutine map_yambo_Gs(yambo_Gs, lookup_array, mapped_indices)
        !> Maps Yambo G-vectors to indices in the local G-vector list using the lookup array
        !> returns mapped indices, a 1D array of size numYamboG
        implicit none
        integer, intent(in)               :: yambo_Gs(:, :)         !3, numYamboG
        integer, intent(in), allocatable  :: lookup_array(:,:,:)
        integer, intent(out), allocatable :: mapped_indices(:)

        integer                          :: i, h, k, l, idx 

        allocate(mapped_indices(size(yambo_Gs, 2)))

        do i = 1, size(yambo_Gs, 2)
            h = yambo_Gs(1, i)
            k = yambo_Gs(2, i)
            l = yambo_Gs(3, i)

            !> Guard: Check if the requested h,k,l are inside the allocated box
            if (h < lbound(lookup_array, 1) .or. h > ubound(lookup_array, 1) .or. &
                k < lbound(lookup_array, 2) .or. k > ubound(lookup_array, 2) .or. &
                l < lbound(lookup_array, 3) .or. l > ubound(lookup_array, 3)) then
                        
                print *, "Error: Yambo requested G-vector (", h, k, l, ")"
                print *, "This is outside the local wavefunction bounds."
                print *, "Check that Yambo NGsBlkXs is <= the wfc2bin cutoff."
                error stop "G-vector mismatch between Yambo and WFC"
            end if


            idx = lookup_array(h, k, l)
            if (idx == 0) then
                print *, "Error: Yambo G-vector (", h, ",", k, ",", l, ") not found in local G-vectors."
                error stop
            end if
            mapped_indices(i) = idx
        end do
    end subroutine map_yambo_Gs


    subroutine scatter_add_dielectric(epsm1_slice, map, numG_total, padded_mat)
        !> Adds the smaller epsm1 slice to the larger padded dielectric matrix
        implicit none
        complex(dp), intent(in)  :: epsm1_slice(:,:) 
        integer, intent(in)      :: map(:)           
        integer, intent(in)      :: numG_total       
        complex(dp), intent(out) :: padded_mat(:, :)
        
        integer :: i, j, row_idx, col_idx, n_sub
        complex(dp), parameter :: one = (1.0_dp, 0.0_dp)
        complex(dp), parameter :: zero = (0.0_dp, 0.0_dp)

        if (size(padded_mat, 1) < numG_total .or. size(padded_mat, 2) < numG_total) then
            print *, "CRITICAL ERROR: padded_mat is too small!"
            print *, "Expected size: ", numG_total, "x", numG_total
            print *, "Actual size:   ", size(padded_mat, 1), "x", size(padded_mat, 2)
            error stop
        end if
        
        n_sub = size(map)
        
        ! Init Identity
        padded_mat = zero
        do i = 1, numG_total
            padded_mat(i, i) = one
        end do
        
        ! Scatter Update
        do j = 1, n_sub
            col_idx = map(j) ! This maps subset col 'j' -> master col 'col_idx'
            
            do i = 1, n_sub
                row_idx = map(i) ! This maps subset row 'i' -> master row 'row_idx'
                
                padded_mat(row_idx, col_idx) = &
                    padded_mat(row_idx, col_idx) + epsm1_slice(i, j)
            end do
        end do
        
    end subroutine scatter_add_dielectric

    subroutine pad_epsm1(epsm1_slice, yambo_Gs, G_vec_crys, padded_epsm1)
        !> Pads the smaller dielectric matrix to the full size using Yambo G-vectors
        implicit none
        complex(dp), intent(in)      :: epsm1_slice(:,:)       ! smaller dielectric matrix
        integer, intent(in)          :: yambo_Gs(:, :)         ! 3, numYamboG
        integer, intent(in)          :: G_vec_crys(:, :)       ! 3, numG
        complex(dp), intent(out)     :: padded_epsm1(:,:)      ! larger padded dielectric matrix
        
        integer,allocatable          :: lookup_array(:,:,:)
        integer,allocatable          :: map(:)
        integer                      :: numG_total

        ! Build lookup table
        call build_lookup_table(G_vec_crys, lookup_array)

        ! Map Yambo G-vectors to local indices
        call map_yambo_Gs(yambo_Gs, lookup_array, map)

        numG_total = size(G_vec_crys, 2)

        ! Scatter add to build padded dielectric matrix
        call scatter_add_dielectric(epsm1_slice, map, numG_total, padded_epsm1)

        deallocate(lookup_array)
        deallocate(map)
    end subroutine pad_epsm1

end module epsm1
