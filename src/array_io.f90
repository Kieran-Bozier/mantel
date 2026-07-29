module array_io

    !>      This module is responsible for reading
    !>      and writing arrays which are stored into
    !>      binary .bin files


    use precision, only: dp, ic
    implicit none

!>Interface is a neat way to make sure calls the right version of function
interface save_array
    module procedure save_array_1d
    module procedure save_complex_array_1d
    module procedure save_int_array_1d
    module procedure save_array_2d
    module procedure save_complex_array_2d
    module procedure save_int_array_2d
    module procedure save_array_3d
    module procedure save_complex_array_3d
    module procedure save_int_array_3d
    module procedure save_array_4d
    module procedure save_complex_array_4d
    module procedure save_int_array_4d
end interface save_array 

interface load_array
    module procedure load_array_1d
    module procedure load_complex_array_1d
    module procedure load_int_array_1d
    module procedure load_array_2d
    module procedure load_complex_array_2d
    module procedure load_int_array_2d
    module procedure load_array_3d
    module procedure load_complex_array_3d
    module procedure load_int_array_3d
    module procedure load_array_4d
    module procedure load_complex_array_4d
    module procedure load_int_array_4d
end interface load_array


contains
!>   First we define implementation for real arrays of different ranks


!>===================================================
!>           1D Implementation
!>====================================================
subroutine save_array_1d(filename, array)
    character(len=*), intent(in) :: filename
    real(dp), intent(in)         :: array(:)
    integer                      :: unit_num 
    integer                      :: dims(1)
    integer                      :: rank_id=1
    integer                      :: type_id=2   !reals will be type 2


    dims = shape(array)
    open(newunit=unit_num, file=filename, status='replace', access='stream', form='unformatted')
    write(unit_num) rank_id
    write(unit_num) type_id
    write(unit_num) dims
    write(unit_num) array
    close(unit_num)
end subroutine save_array_1d

subroutine load_array_1d(filename, array)
    character(len=*), intent(in) :: filename
    real(dp), allocatable, intent(out)             :: array(:)
    integer                      :: unit_num 
    integer                      :: dims(1)
    integer                      :: rank_id
    integer                      :: type_id

    open(newunit=unit_num, file=filename, status='old', access='stream', form='unformatted')
    read(unit_num) rank_id
    if (rank_id /= 1) then
        print *, "Problems loading ", filename 
        print *, "Error: Expected 1D array but file indicates rank ", rank_id
        close(unit_num)
        error stop "Fatal error loading array"
    end if

    read(unit_num) type_id
    if (type_id /= 2) then
        print *, "Problems loading ", filename 
        print *, "Error: Expected real array (type 2) but file indicates type ", type_id
        close(unit_num)
        error stop "Fatal error loading array"
    end if

    read(unit_num) dims
    if (allocated(array)) deallocate(array)
    allocate(array(dims(1)))
    read(unit_num) array
    close(unit_num)
end subroutine load_array_1d

!>====================================================
!>            2D Implementation
!>=====================================================
subroutine save_array_2d(filename, array)
    character(len=*), intent(in) :: filename
    real(dp), intent(in)             :: array(:, :)
    integer                      :: unit_num 
    integer                      :: dims(2)
    integer                      :: rank_id=2
    integer                      :: type_id=2   !reals will be type 2

    dims = shape(array)
    open(newunit=unit_num, file=filename, status='replace', access='stream', form='unformatted')
    write(unit_num) rank_id
    write(unit_num) type_id
    write(unit_num) dims
    write(unit_num) array
    close(unit_num)
end subroutine save_array_2d

subroutine load_array_2d(filename, array)
    character(len=*), intent(in) :: filename
    real(dp), allocatable, intent(out)             :: array(:, :)
    integer                      :: unit_num 
    integer                      :: dims(2)
    integer                      :: rank_id
    integer                      :: type_id

    open(newunit=unit_num, file=filename, status='old', access='stream', form='unformatted')
    read(unit_num) rank_id
    if (rank_id /= 2) then
        print *, "Problems loading ", filename 
        print *, "Error: Expected 2D array but file indicates rank ", rank_id
        close(unit_num)
        error stop "Fatal error loading array"
    end if

    read(unit_num) type_id
    if (type_id /= 2) then
        print *, "Problems loading ", filename 
        print *, "Error: Expected real array (type 2) but file indicates type ", type_id
        close(unit_num)
        error stop "Fatal error loading array"
    end if
    
    read(unit_num) dims
    if (allocated(array)) deallocate(array)
    allocate(array(dims(1), dims(2)))
    read(unit_num) array
    close(unit_num)
end subroutine load_array_2d

!>====================================================
!>            3D Implementation
!>=====================================================
subroutine save_array_3d(filename, array)
    character(len=*), intent(in) :: filename
    real(dp), intent(in)             :: array(:, :, :)
    integer                      :: unit_num 
    integer                      :: dims(3)
    integer                      :: rank_id=3
    integer                      :: type_id=2   !reals will be type 2


    dims = shape(array)
    open(newunit=unit_num, file=filename, status='replace', access='stream', form='unformatted')
    write(unit_num) rank_id
    write(unit_num) type_id
    write(unit_num) dims
    write(unit_num) array
    close(unit_num)
end subroutine save_array_3d

subroutine load_array_3d(filename, array)
    character(len=*), intent(in) :: filename
    real(dp), allocatable, intent(out)             :: array(:, :, :)
    integer                      :: unit_num 
    integer                      :: dims(3)
    integer                      :: rank_id
    integer                      :: type_id


    open(newunit=unit_num, file=filename, status='old', access='stream', form='unformatted')
    read(unit_num) rank_id
    if (rank_id /= 3) then
        print *, "Problems loading ", filename 
        print *, "Error: Expected 3D array but file indicates rank ", rank_id
        close(unit_num)
        error stop "Fatal error loading array"
    end if

    read(unit_num) type_id
    if (type_id /= 2) then
        print *, "Problems loading ", filename 
        print *, "Error: Expected real array (type 2) but file indicates type ", type_id
        close(unit_num)
        error stop "Fatal error loading array"
    end if
    
    read(unit_num) dims
    if (allocated(array)) deallocate(array)
    allocate(array(dims(1), dims(2), dims(3)))
    read(unit_num) array
    close(unit_num)
end subroutine load_array_3d




!>====================================================
!>            4D Implementation
!>=====================================================
subroutine save_array_4d(filename, array)
    character(len=*), intent(in) :: filename
    real(dp), intent(in)             :: array(:, :, :, :)
    integer                      :: unit_num 
    integer                      :: dims(4)
    integer                      :: rank_id=4
    integer                      :: type_id=2   !reals will be type 2


    dims = shape(array)
    open(newunit=unit_num, file=filename, status='replace', access='stream', form='unformatted')
    write(unit_num) rank_id
    write(unit_num) type_id
    write(unit_num) dims
    write(unit_num) array
    close(unit_num)
end subroutine save_array_4d

subroutine load_array_4d(filename, array)
    character(len=*), intent(in) :: filename
    real(dp), allocatable, intent(out)             :: array(:, :, :, :)
    integer                      :: unit_num 
    integer                      :: dims(4)
    integer                      :: rank_id
    integer                      :: type_id

    open(newunit=unit_num, file=filename, status='old', access='stream', form='unformatted')
    read(unit_num) rank_id
    if (rank_id /= 4) then
        print *, "Problems loading ", filename 
        print *, "Error: Expected 4D array but file indicates rank ", rank_id
        close(unit_num)
        error stop "Fatal error loading array"
    end if

    read(unit_num) type_id
    if (type_id /= 2) then
        print *, "Problems loading ", filename 
        print *, "Error: Expected real array (type 2) but file indicates type ", type_id
        close(unit_num)
        error stop "Fatal error loading array"
    end if
    
    read(unit_num) dims
    if (allocated(array)) deallocate(array)
    allocate(array(dims(1), dims(2), dims(3), dims(4)))
    read(unit_num) array
    close(unit_num)
end subroutine load_array_4d


!>  Now we repeat, but for complex arrays


!>===================================================
!>           1D COMPLEX Implementation
!>====================================================
subroutine save_complex_array_1d(filename, array)
    character(len=*), intent(in) :: filename
    complex(dp), intent(in)             :: array(:)
    integer                      :: unit_num 
    integer                      :: dims(1)
    integer                      :: rank_id=1
    integer                      :: type_id=3   !complex will be type 3


    dims = shape(array)
    open(newunit=unit_num, file=filename, status='replace', access='stream', form='unformatted')
    write(unit_num) rank_id
    write(unit_num) type_id
    write(unit_num) dims
    write(unit_num) array
    close(unit_num)
end subroutine save_complex_array_1d

subroutine load_complex_array_1d(filename, array)
    character(len=*), intent(in) :: filename
    complex(dp), allocatable, intent(out)             :: array(:)
    integer                      :: unit_num 
    integer                      :: dims(1)
    integer                      :: rank_id
    integer                      :: type_id

    open(newunit=unit_num, file=filename, status='old', access='stream', form='unformatted')
    read(unit_num) rank_id
    if (rank_id /= 1) then
        print *, "Problems loading ", filename 
        print *, "Error: Expected 1D array but file indicates rank ", rank_id
        close(unit_num)
        error stop "Fatal error loading array"
    end if

    read(unit_num) type_id
    if (type_id /= 3) then
        print *, "Problems loading ", filename 
        print *, "Error: Expected complex array (type 3) but file indicates type ", type_id
        close(unit_num)
        error stop "Fatal error loading array"
    end if

    read(unit_num) dims
    if (allocated(array)) deallocate(array)
    allocate(array(dims(1)))
    read(unit_num) array
    close(unit_num)
end subroutine load_complex_array_1d

!>====================================================
!>            2D COMPLEX Implementation
!>=====================================================
subroutine save_complex_array_2d(filename, array)
    character(len=*), intent(in) :: filename
    complex(dp), intent(in)             :: array(:, :)
    integer                      :: unit_num 
    integer                      :: dims(2)
    integer                      :: rank_id=2
    integer                      :: type_id=3   !complex will be type 3

    dims = shape(array)
    open(newunit=unit_num, file=filename, status='replace', access='stream', form='unformatted')
    write(unit_num) rank_id
    write(unit_num) type_id
    write(unit_num) dims
    write(unit_num) array
    close(unit_num)
end subroutine save_complex_array_2d

subroutine load_complex_array_2d(filename, array)
    character(len=*), intent(in) :: filename
    complex(dp), allocatable, intent(out)             :: array(:, :)
    integer                      :: unit_num 
    integer                      :: dims(2)
    integer                      :: rank_id
    integer                      :: type_id

    open(newunit=unit_num, file=filename, status='old', access='stream', form='unformatted')
    read(unit_num) rank_id
    if (rank_id /= 2) then
        print *, "Problems loading ", filename 
        print *, "Error: Expected 2D array but file indicates rank ", rank_id
        close(unit_num)
        error stop "Fatal error loading array"
    end if

    read(unit_num) type_id
    if (type_id /= 3) then
        print *, "Problems loading ", filename 
        print *, "Error: Expected complex array (type 3) but file indicates type ", type_id
        close(unit_num)
        error stop "Fatal error loading array"
    end if
    
    read(unit_num) dims
    if (allocated(array)) deallocate(array)
    allocate(array(dims(1), dims(2)))
    read(unit_num) array
    close(unit_num)
end subroutine load_complex_array_2d

!>====================================================
!>            3D COMPLEX Implementation
!>=====================================================
subroutine save_complex_array_3d(filename, array)
    character(len=*), intent(in) :: filename
    complex(dp), intent(in)             :: array(:, :, :)
    integer                      :: unit_num 
    integer                      :: dims(3)
    integer                      :: rank_id=3
    integer                      :: type_id=3   !complex will be type 3


    dims = shape(array)
    open(newunit=unit_num, file=filename, status='replace', access='stream', form='unformatted')
    write(unit_num) rank_id
    write(unit_num) type_id
    write(unit_num) dims
    write(unit_num) array
    close(unit_num)
end subroutine save_complex_array_3d

subroutine load_complex_array_3d(filename, array)
    character(len=*), intent(in) :: filename
    complex(dp), allocatable, intent(out)             :: array(:, :, :)
    integer                      :: unit_num 
    integer                      :: dims(3)
    integer                      :: rank_id
    integer                      :: type_id


    open(newunit=unit_num, file=filename, status='old', access='stream', form='unformatted')
    read(unit_num) rank_id
    if (rank_id /= 3) then
        print *, "Problems loading ", filename 
        print *, "Error: Expected 3D array but file indicates rank ", rank_id
        close(unit_num)
        error stop "Fatal error loading array"
    end if

    read(unit_num) type_id
    if (type_id /= 3) then
        print *, "Problems loading ", filename 
        print *, "Error: Expected complex array (type 3) but file indicates type ", type_id
        close(unit_num)
        error stop "Fatal error loading array"
    end if
    
    read(unit_num) dims
    if (allocated(array)) deallocate(array)
    allocate(array(dims(1), dims(2), dims(3)))
    read(unit_num) array
    close(unit_num)
end subroutine load_complex_array_3d




!>====================================================
!>            4D COMPLEX Implementation
!>=====================================================
subroutine save_complex_array_4d(filename, array)
    character(len=*), intent(in) :: filename
    complex(dp), intent(in)             :: array(:, :, :, :)
    integer                      :: unit_num 
    integer                      :: dims(4)
    integer                      :: rank_id=4
    integer                      :: type_id=3   !complex will be type 3

    dims = shape(array)
    open(newunit=unit_num, file=filename, status='replace', access='stream', form='unformatted')
    write(unit_num) rank_id
    write(unit_num) type_id
    write(unit_num) dims
    write(unit_num) array
    close(unit_num)
end subroutine save_complex_array_4d

subroutine load_complex_array_4d(filename, array)
    character(len=*), intent(in) :: filename
    complex(dp), allocatable, intent(out)             :: array(:, :, :, :)
    integer                      :: unit_num 
    integer                      :: dims(4)
    integer                      :: rank_id
    integer                      :: type_id

    open(newunit=unit_num, file=filename, status='old', access='stream', form='unformatted')
    read(unit_num) rank_id
    if (rank_id /= 4) then
        print *, "Problems loading ", filename 
        print *, "Error: Expected 4D array but file indicates rank ", rank_id
        close(unit_num)
        error stop "Fatal error loading array"
    end if

    read(unit_num) type_id
    if (type_id /= 3) then
        print *, "Problems loading ", filename 
        print *, "Error: Expected complex array (type 3) but file indicates type ", type_id
        close(unit_num)
        error stop "Fatal error loading array"
    end if
    
    read(unit_num) dims
    if (allocated(array)) deallocate(array)
    allocate(array(dims(1), dims(2), dims(3), dims(4)))
    read(unit_num) array
    close(unit_num)
end subroutine load_complex_array_4d


!> And finally for integers (type_id = 1)

!>===================================================
!>           1D INTEGER Implementation
!>====================================================
subroutine save_int_array_1d(filename, array)
    character(len=*), intent(in) :: filename
    integer(ic), intent(in)             :: array(:)
    integer                      :: unit_num 
    integer                      :: dims(1)
    integer                      :: rank_id=1
    integer                      :: type_id=1   !int will be type 1


    dims = shape(array)
    open(newunit=unit_num, file=filename, status='replace', access='stream', form='unformatted')
    write(unit_num) rank_id
    write(unit_num) type_id
    write(unit_num) dims
    write(unit_num) array
    close(unit_num)
end subroutine save_int_array_1d

subroutine load_int_array_1d(filename, array)
    character(len=*), intent(in) :: filename
    integer(ic), allocatable, intent(out)             :: array(:)
    integer                      :: unit_num 
    integer                      :: dims(1)
    integer                      :: rank_id
    integer                      :: type_id

    open(newunit=unit_num, file=filename, status='old', access='stream', form='unformatted')
    read(unit_num) rank_id
    if (rank_id /= 1) then
        print *, "Problems loading ", filename 
        print *, "Error: Expected 1D array but file indicates rank ", rank_id
        close(unit_num)
        error stop "Fatal error loading array"
    end if

    read(unit_num) type_id
    if (type_id /= 1) then
        print *, "Problems loading ", filename 
        print *, "Error: Expected integer array (type 1) but file indicates type ", type_id
        close(unit_num)
        error stop "Fatal error loading array"
    end if

    read(unit_num) dims
    if (allocated(array)) deallocate(array)
    allocate(array(dims(1)))
    read(unit_num) array
    close(unit_num)
end subroutine load_int_array_1d

!>====================================================
!>            2D COMPLEX Implementation
!>=====================================================
subroutine save_int_array_2d(filename, array)
    character(len=*), intent(in) :: filename
    integer(ic), intent(in)             :: array(:, :)
    integer                      :: unit_num 
    integer                      :: dims(2)
    integer                      :: rank_id=2
    integer                      :: type_id=1   !int will be type 1

    dims = shape(array)
    open(newunit=unit_num, file=filename, status='replace', access='stream', form='unformatted')
    write(unit_num) rank_id
    write(unit_num) type_id
    write(unit_num) dims
    write(unit_num) array
    close(unit_num)
end subroutine save_int_array_2d

subroutine load_int_array_2d(filename, array)
    character(len=*), intent(in) :: filename
    integer(ic), allocatable, intent(out)             :: array(:, :)
    integer                      :: unit_num 
    integer                      :: dims(2)
    integer                      :: rank_id
    integer                      :: type_id

    open(newunit=unit_num, file=filename, status='old', access='stream', form='unformatted')
    read(unit_num) rank_id
    if (rank_id /= 2) then
        print *, "Problems loading ", filename 
        print *, "Error: Expected 2D array but file indicates rank ", rank_id
        close(unit_num)
        error stop "Fatal error loading array"
    end if

    read(unit_num) type_id
    if (type_id /= 1) then
        print *, "Problems loading ", filename 
        print *, "Error: Expected integer array (type 1) but file indicates type ", type_id
        close(unit_num)
        error stop "Fatal error loading array"
    end if
    
    read(unit_num) dims
    if (allocated(array)) deallocate(array)
    allocate(array(dims(1), dims(2)))
    read(unit_num) array
    close(unit_num)
end subroutine load_int_array_2d

!>====================================================
!>            3D COMPLEX Implementation
!>=====================================================
subroutine save_int_array_3d(filename, array)
    character(len=*), intent(in) :: filename
    integer(ic), intent(in)             :: array(:, :, :)
    integer                      :: unit_num 
    integer                      :: dims(3)
    integer                      :: rank_id=3
    integer                      :: type_id=1   !integer will be type 1


    dims = shape(array)
    open(newunit=unit_num, file=filename, status='replace', access='stream', form='unformatted')
    write(unit_num) rank_id
    write(unit_num) type_id
    write(unit_num) dims
    write(unit_num) array
    close(unit_num)
end subroutine save_int_array_3d

subroutine load_int_array_3d(filename, array)
    character(len=*), intent(in) :: filename
    integer(ic), allocatable, intent(out)             :: array(:, :, :)
    integer                      :: unit_num 
    integer                      :: dims(3)
    integer                      :: rank_id
    integer                      :: type_id


    open(newunit=unit_num, file=filename, status='old', access='stream', form='unformatted')
    read(unit_num) rank_id
    if (rank_id /= 3) then
        print *, "Problems loading ", filename 
        print *, "Error: Expected 3D array but file indicates rank ", rank_id
        close(unit_num)
        error stop "Fatal error loading array"
    end if

    read(unit_num) type_id
    if (type_id /= 1) then
        print *, "Problems loading ", filename 
        print *, "Error: Expected integer array (type 1) but file indicates type ", type_id
        close(unit_num)
        error stop "Fatal error loading array"
    end if
    
    read(unit_num) dims
    if (allocated(array)) deallocate(array)
    allocate(array(dims(1), dims(2), dims(3)))
    read(unit_num) array
    close(unit_num)
end subroutine load_int_array_3d




!>====================================================
!>            4D COMPLEX Implementation
!>=====================================================
subroutine save_int_array_4d(filename, array)
    character(len=*), intent(in) :: filename
    integer(ic), intent(in)             :: array(:, :, :, :)
    integer                      :: unit_num 
    integer                      :: dims(4)
    integer                      :: rank_id=4
    integer                      :: type_id=1  !integer will be type 1

    dims = shape(array)
    open(newunit=unit_num, file=filename, status='replace', access='stream', form='unformatted')
    write(unit_num) rank_id
    write(unit_num) type_id
    write(unit_num) dims
    write(unit_num) array
    close(unit_num)
end subroutine save_int_array_4d

subroutine load_int_array_4d(filename, array)
    character(len=*), intent(in) :: filename
    integer(ic), allocatable, intent(out)             :: array(:, :, :, :)
    integer                      :: unit_num 
    integer                      :: dims(4)
    integer                      :: rank_id
    integer                      :: type_id

    open(newunit=unit_num, file=filename, status='old', access='stream', form='unformatted')
    read(unit_num) rank_id
    if (rank_id /= 4) then
        print *, "Problems loading ", filename 
        print *, "Error: Expected 4D array but file indicates rank ", rank_id
        close(unit_num)
        error stop "Fatal error loading array"
    end if

    read(unit_num) type_id
    if (type_id /= 1) then
        print *, "Problems loading ", filename 
        print *, "Error: Expected integer array (type 1) but file indicates type ", type_id
        close(unit_num)
        error stop "Fatal error loading array"
    end if
    
    read(unit_num) dims
    if (allocated(array)) deallocate(array)
    allocate(array(dims(1), dims(2), dims(3), dims(4)))
    read(unit_num) array
    close(unit_num)
end subroutine load_int_array_4d




end module array_io
