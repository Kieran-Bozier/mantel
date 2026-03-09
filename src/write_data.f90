module write_data

    !>     This module handles writing data to binary files, specifically the W matrix.
    
    use precision,                  only: dp 
    use array_io,                   only: save_array 

    implicit none 

contains
    subroutine write_W(W, iq)
        !> Writes the W matrix to a binary file
        complex(dp), intent(in)                 :: W(:, :, :)               !numBand, numBand, numK
        integer, intent(in)                     :: iq

        character(len=256)                      :: filename

        write(filename, '("W_iq", I0, ".bin")') iq
        call save_array(trim(filename), W)
    end subroutine write_W

end module write_data