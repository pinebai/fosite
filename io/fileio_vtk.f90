!#############################################################################
!#                                                                           #
!# fosite - 2D hydrodynamical simulation program                             #
!# module: fileio_vtk.f90                                                    #
!#                                                                           #
!# Copyright (C) 2010 Björn Sperling <sperling@astrophysik.uni-kiel.de>      #
!#                                                                           #
!# This program is free software; you can redistribute it and/or modify      #
!# it under the terms of the GNU General Public License as published by      #
!# the Free Software Foundation; either version 2 of the License, or (at     #
!# your option) any later version.                                           #
!#                                                                           #
!# This program is distributed in the hope that it will be useful, but       #
!# WITHOUT ANY WARRANTY; without even the implied warranty of                #
!# MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE, GOOD TITLE or        #
!# NON INFRINGEMENT.  See the GNU General Public License for more            #
!# details.                                                                  #
!#                                                                           #
!# You should have received a copy of the GNU General Public License         #
!# along with this program; if not, write to the Free Software               #
!# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.                 #
!#                                                                           #
!#############################################################################

!----------------------------------------------------------------------------!
! module for vtk I/O (structured grids)
!----------------------------------------------------------------------------!
#ifdef FORTRAN_STREAMS
#define HAVE_VTK
#elif NECSX9
#define HAVE_VTK
#define NOSTREAM
#elif NECSX8
#define HAVE_VTK
#define NOSTREAM
#endif
MODULE fileio_vtk
  USE fileio_common
  USE geometry_common, ONLY : Geometry_TYP, GetName, GetType
  USE geometry_generic
  USE mesh_common, ONLY : Mesh_TYP
  USE physics_common, ONLY : Physics_TYP, GetName, GetType
  USE timedisc_common, ONLY : Timedisc_TYP
  IMPLICIT NONE
  !--------------------------------------------------------------------------!
  PRIVATE
  !--------------------------------------------------------------------------!
  PUBLIC :: &
       ! types
       FileIO_TYP, &
       ! constants

       ! methods
       InitFileio_vtk, &
       OpenFile_vtk, &
       CloseFile_vtk, &
       WriteHeader_vtk, &
       ReadHeader_vtk, &
       WriteTimestamp_vtk, &
       ReadTimestamp_vtk,&
       WriteDataset_vtk, &
       CloseFileio_vtk
  !--------------------------------------------------------------------------!

   INTEGER, PARAMETER      :: MAXLEN   = 500       ! max number of characters os static string
   INTEGER, PARAMETER      :: MAXCOMP  = 9         ! max. number of components (9 = rank 2, dim 3)
   CHARACTER(1), PARAMETER :: end_rec  = char(10)  ! end-character for binary-record finalize
   INTEGER(KIND = 4)       :: N_Byte               ! number of byte to be written (must be 4 byte!!!)
   CHARACTER(len=MAXLEN)   :: s_buffer,s_buffer2   ! buffer string
   INTEGER                 :: indent               ! indent pointer
   INTEGER                 :: SIZEOF_F
!----------------------------------------------------------------------------------------------------------------------------------

CONTAINS
  
  SUBROUTINE InitFileio_vtk(this,Mesh,Physics,fmt,filename,stoptime,dtwall,&
       count,fcycles,unit)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(FileIO_TYP)  :: this
    TYPE(Mesh_TYP)    :: Mesh
    TYPE(Physics_TYP) :: Physics
    INTEGER           :: fmt
    CHARACTER(LEN=*)  :: filename
    REAL              :: stoptime
    INTEGER           :: dtwall
    INTEGER           :: count
    INTEGER           :: fcycles
    INTEGER, OPTIONAL :: unit
    !------------------------------------------------------------------------!
    INTEGER           :: iTIPO, err,k
    CHARACTER, POINTER:: cTIPO(:)
    CHARACTER(LEN=4)  :: cTIPO4
    CHARACTER(LEN=8)  :: cTIPO8
    CHARACTER(LEN=16) :: cTIPO16
    REAL              :: rTIPO1, rTIPO2
    !------------------------------------------------------------------------!
    INTENT(IN)        :: Mesh,Physics,fmt,filename,stoptime,count,fcycles,unit
    INTENT(INOUT)     :: this
    !------------------------------------------------------------------------!
!rank=0 Prozess zusätzlich eine pvts erzeugen!
    CALL InitFileIO(this,fmt,"VTK",filename,'vts',fcycles,.TRUE.,unit)
       this%stoptime = stoptime
       this%dtwall   = dtwall
       this%time     = 0.
       this%count    = count
       this%step     = 0
       this%ioffset  = 0
#ifndef HAVE_VTK
    CALL Error(this,"InitFileIO","VTK support disabled")
#endif
    IF (fcycles .NE. count+1) CALL Error(this,'InitFileIO','VTK need filecycles = count+1')

    !HOW big is a REAL?
    rTIPO1 = ACOS(0.0)
    cTIPO4 = transfer(rTIPO1,cTIPO4)
    rTIPO2 = transfer(cTIPO4,rTIPO2)
    IF (rTIPO2 == rTIPO1) THEN
       SIZEOF_F = 4
    ELSE
       cTIPO8 = transfer(rTIPO1,cTIPO8)
       rTIPO2 = transfer(cTIPO8,rTIPO2)
       IF (rTIPO2 == rTIPO1) THEN
          SIZEOF_F = 8
       ELSE
          cTIPO16 = transfer(rTIPO1,cTIPO16)
          rTIPO2 = transfer(cTIPO16,rTIPO2)
          IF (rTIPO2 == rTIPO1) THEN
             SIZEOF_F = 16
          ELSE
             CALL Error(this, "InitFileio_vtk", "Could not estimate size of float type")
          END IF
       END IF
    END IF

    ! save size of floats to string: realfmt
    write(s_buffer,'(I4)',IOSTAT=this%error) 8*SIZEOF_F
    write(this%realfmt,'(A,A,A)',IOSTAT=this%error)'"Float',trim(AdjustL(s_buffer)),'"'

    IF (BIT_SIZE(N_BYTE) .NE. 4*8) &
          CALL Error(this, "InitFileio_vtk", "INTERGER(KIND=4)::N_Byte failed")

    !endianness
    k = BIT_SIZE(iTIPO)/8
    ALLOCATE(cTIPO(k),STAT = err)
       IF (err.NE.0) &
         CALL Error(this, "InitFileio_vtk", "Unable to allocate memory.")
    cTIPO(1)='A'
    !cTIPO(2:k-1) = That's of no importance.
    cTIPO(k)='B'

    iTIPO = transfer(cTIPO, iTIPO)
    DEALLOCATE(cTIPO)
    !Test of 'B'=b'01000010' ('A'=b'01000001')
    IF (BTEST(iTIPO,1)) THEN
       write(this%endianness,'(A)',IOSTAT=this%error)'"BigEndian"'
    ELSE
       write(this%endianness,'(A)',IOSTAT=this%error)'"LittleEndian"'       
    END IF

    ALLOCATE(this%vtktemp(Mesh%IGMIN:Mesh%IGMAX,Mesh%JGMIN:Mesh%JGMAX,2),STAT = err)
    IF (err.NE.0) &
         CALL Error(this, "InitFileio_vtk", "Unable to allocate memory.")

  END SUBROUTINE InitFileIO_vtk


  SUBROUTINE OpenFile_vtk(this,action)
     IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(FileIO_TYP) :: this
    INTEGER          :: action
    !------------------------------------------------------------------------!
    INTENT(IN)       :: action
    INTENT(INOUT)    :: this
    !------------------------------------------------------------------------!
#ifdef HAVE_VTK
    SELECT CASE(action)
    CASE(READONLY)
       OPEN(this%unit, FILE=GetFilename(this), &
         STATUS     = 'OLD',          &
#ifndef NOSTREAM 
         ACCESS     = 'STREAM' ,   &
#else
         FORM='UNFORMATTED',&
#endif
         action     = 'READ',         &
         POSITION   = 'REWIND',       &
         iostat     = this%error)
    CASE(READEND)
       open(this%unit, FILE=GetFilename(this), &
         STATUS     = 'OLD',          &
#ifndef NOSTREAM
         ACCESS     = 'STREAM' ,   &
#else
         FORM='UNFORMATTED',&
#endif
         action     = 'READ',         &
         POSITION   = 'APPEND',       &
         iostat     = this%error)
    CASE(REPLACE)
       open(this%unit, FILE=GetFilename(this), &
         STATUS     = 'REPLACE',      &
#ifndef NOSTREAM
         ACCESS     = 'STREAM' ,   &
#else
         FORM='UNFORMATTED',&
#endif
         action     = 'WRITE',        &
         POSITION   = 'REWIND',       &
         iostat     = this%error)
    CASE(APPEND)
       open(this%unit, FILE=GetFilename(this), &
         STATUS     = 'OLD',          &
#ifndef NOSTREAM
         ACCESS     = 'STREAM' ,   &
#else
         FORM='UNFORMATTED',&
#endif
         action     = 'READWRITE',    &
         POSITION   = 'APPEND',       &
         iostat     = this%error)
    CASE DEFAULT
       CALL Error(this,"OpenFile","Unknown access mode.")
    END SELECT
    IF (this%error.NE. 0) CALL Error(this,"OpenFile_vtk","Can't open file")
#endif
  END SUBROUTINE OpenFile_vtk


  SUBROUTINE CloseFile_vtk(this)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(FileIO_TYP) :: this
    !------------------------------------------------------------------------!
    INTENT(INOUT)    :: this
    !------------------------------------------------------------------------!

    CLOSE(this%unit,IOSTAT=this%error)
    IF(this%error .NE. 0) CALL ERROR(this, "CloseFileIO_vtk", "Can't close file")
  END SUBROUTINE CloseFile_vtk


  SUBROUTINE WriteHeader_vtk(this,Mesh,Physics)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(FileIO_TYP)  :: this
    TYPE(Mesh_TYP)    :: Mesh
    TYPE(Physics_TYP) :: Physics
    !------------------------------------------------------------------------!
    INTEGER :: i,j,k
    !------------------------------------------------------------------------!
    INTENT(IN)        :: Mesh,Physics
    INTENT(INOUT)     :: this
    !------------------------------------------------------------------------!

    this%ioffset = 0
    write(this%unit, IOSTAT=this%error)'<?xml version="1.0"?>'//end_rec
    write(this%unit, IOSTAT=this%error)&
      '<VTKFile type="StructuredGrid" version="0.1" byte_order='//this%endianness//'>'//end_rec
    indent = 2
    write(s_buffer,fmt='(A,6(I7),A)',IOSTAT=this%error)&
           repeat(' ',indent)//'<StructuredGrid WholeExtent="'&
          ,Mesh%IMIN,Mesh%IMAX+1,Mesh%JMIN,Mesh%JMAX+1,1,1,'">'
    write(this%unit, IOSTAT=this%error)trim(s_buffer)//end_rec
    indent = indent + 2
    write(s_buffer,fmt='(A,6(I7),A)',IOSTAT=this%error)&
           repeat(' ',indent)//'<Piece Extent="'&
          ,Mesh%IMIN,Mesh%IMAX+1,Mesh%JMIN,Mesh%JMAX+1,1,1,'">'
    indent = indent + 2
    write(this%unit,IOSTAT=this%error)trim(s_buffer)//end_rec
    write(this%unit,IOSTAT=this%error)repeat(' ',indent)//'<Points>'//end_rec
    indent = indent + 2

    write(this%unit,IOSTAT=this%error)repeat(' ',indent)&
          //'<DataArray type='//this%realfmt//' NumberOfComponents="3" Name="Point"'&
          //' format="appended" offset="0">'//end_rec
    N_Byte  = 3*(Mesh%IMAX-Mesh%IMIN+2)*(Mesh%JMAX-Mesh%JMIN+2)*SIZEOF_F
    this%ioffset = this%ioffset + N_Byte + 4 !sizeof(N_Byte) must be 4!!!!!

    write(this%unit,IOSTAT=this%error)repeat(' ',indent)//'</DataArray>'//end_rec
    indent = indent - 2
    write(this%unit,IOSTAT=this%error)repeat(' ',indent)//'</Points>'//end_rec

    write(this%unit,IOSTAT=this%error)repeat(' ',indent)//'<CellData>'//end_rec
    indent = indent + 2


    DO k = 2, Physics%nstruc
       write(s_buffer,fmt='(I8)',IOSTAT=this%error)this%ioffset
       write(s_buffer2,fmt='(I3)',IOSTAT=this%error)Physics%structure(k)%dim**Physics%structure(k)%rank
       write(this%unit,IOSTAT=this%error)repeat(' ',indent)&
       //'<DataArray type='//this%realfmt//' NumberOfComponents="',trim(s_buffer2),&
        '" Name="'//TRIM(Physics%structure(k)%name)&
       //'" format="appended" offset="',trim(s_buffer),'"/>'//end_rec

       N_Byte  = Physics%structure(k)%dim**Physics%structure(k)%rank&
                *(Mesh%IMAX-Mesh%IMIN+1)*(Mesh%JMAX-Mesh%JMIN+1)*SIZEOF_F
       this%ioffset = this%ioffset + N_Byte + 4 !sizeof(N_Byte) must be 4!!
    END DO

    indent = indent - 2
    write(this%unit,IOSTAT=this%error)repeat(' ',indent)//'</CellData>'//end_rec
    indent = indent -2
    write(this%unit,iostat=this%error)repeat(' ',indent)//'</Piece>'//end_rec
    indent = indent -2
    write(this%unit,iostat=this%error)repeat(' ',indent)//'</StructuredGrid>'//end_rec
    write(this%unit,iostat=this%error)repeat(' ',indent)//'<AppendedData encoding="raw">'//end_rec
    write(this%unit,iostat=this%error)'_'
    N_Byte = 3*(Mesh%IMAX-Mesh%IMIN+2)*(Mesh%JMAX-Mesh%JMIN+2)*SIZEOF_F
    write(this%unit,iostat=this%error)N_Byte

    !write mesh
    do j=Mesh%JMIN,Mesh%JMAX+1
       do i=Mesh%IMIN,Mesh%IMAX+1
          write(this%unit,IOSTAT=this%error)Mesh%cpcart(i,j,1,1)
          write(this%unit,IOSTAT=this%error)Mesh%cpcart(i,j,1,2)
          write(this%unit,IOSTAT=this%error)0.0
       end do
    end do
    
  END SUBROUTINE WriteHeader_vtk

  SUBROUTINE ReadHeader_vtk(this,success)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(FileIO_TYP) :: this
    LOGICAL          :: success
    !------------------------------------------------------------------------!
    INTENT(OUT)      :: success
    INTENT(INOUT)    :: this
    !------------------------------------------------------------------------!
    success = .FALSE.
  END SUBROUTINE ReadHeader_vtk

  SUBROUTINE WriteTimestamp_vtk(this,time)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(FileIO_TYP) :: this
    REAL             :: time
    !------------------------------------------------------------------------!
    INTENT(IN)       :: time
    INTENT(INOUT)    :: this
    !------------------------------------------------------------------------!

  END SUBROUTINE WriteTimestamp_vtk

  SUBROUTINE ReadTimestamp_vtk(this,time)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(FileIO_TYP) :: this
    REAL             :: time
    !------------------------------------------------------------------------!
    INTENT(OUT)       :: time
    INTENT(INOUT)    :: this
    !------------------------------------------------------------------------!
    time = 0.0
  END SUBROUTINE ReadTimestamp_vtk

  SUBROUTINE WriteDataset_vtk(this,Mesh,Physics,Timedisc)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(FileIO_TYP)  :: this
    TYPE(Mesh_TYP)    :: Mesh
    TYPE(Physics_TYP) :: Physics
    TYPE(Timedisc_TYP):: Timedisc
    !------------------------------------------------------------------------!
    INTEGER           :: i,j,k,m, spos, epos, n
    !------------------------------------------------------------------------!
    INTENT(IN)        :: Mesh,Physics,Timedisc
    INTENT(INOUT)     :: this
    !------------------------------------------------------------------------!

  DO k = 2, Physics%nstruc
       n = Physics%structure(k)%dim**Physics%structure(k)%rank
       N_Byte  = n*(Mesh%IMAX-Mesh%IMIN+1)*(Mesh%JMAX-Mesh%JMIN+1)*SIZEOF_F 
       write(this%unit,iostat=this%error)N_Byte
     
       spos = Physics%structure(k)%pos
       epos = spos + n -1
       IF ( n > 1) THEN
          !no scalar => coordinate transformation (only first 2 dims!)
          CALL Convert2Cartesian(Mesh%geometry,Mesh%bcenter(:,:,:),&
                                 Timedisc%pvar(:,:,spos:spos+1),this%vtktemp)
       END IF

       do j=Mesh%JMIN,Mesh%JMAX
          do i=Mesh%IMIN,Mesh%IMAX
             IF (n > 1) THEN
                write(this%unit,IOSTAT=this%error)this%vtktemp(i,j,1)
                write(this%unit,IOSTAT=this%error)this%vtktemp(i,j,2)
                do m=spos+2, epos
                   write(this%unit,IOSTAT=this%error)Timedisc%pvar(i,j,m)
                end do
             ELSE
                   write(this%unit,IOSTAT=this%error)Timedisc%pvar(i,j,spos)
             END IF
          end do
       end do
    END DO

    write(this%unit,IOSTAT=this%error)end_rec  
    write(this%unit,IOSTAT=this%error)repeat(' ',indent)//'</AppendedData>'//end_rec
    indent = 0 
    write(this%unit,iostat=this%error)'</VTKFile>'//end_rec
      
  END SUBROUTINE WriteDataset_vtk

  SUBROUTINE CloseFileIO_vtk(this)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(FileIO_TYP) :: this
    !------------------------------------------------------------------------!
    INTENT(INOUT)    :: this
    !------------------------------------------------------------------------!
    DEALLOCATE(this%vtktemp) 
  END SUBROUTINE CloseFileIO_vtk
END MODULE fileio_vtk