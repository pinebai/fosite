!#############################################################################
!#                                                                           #
!# fosite - 2D hydrodynamical simulation program                             #
!# module: reconstruction_common.f90                                         #
!#                                                                           #
!# Copyright (C) 2006-2014                                                   #
!# Tobias Illenseer <tillense@astrophysik.uni-kiel.de>                       #
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
!> \defgroup reconstruction reconstruction
!! \{
!! \brief Family of reconstruction modules
!! \}
!----------------------------------------------------------------------------!
!> \author Tobias Illenseer
!!
!! \brief basic reconstruction module
!!
!! \extends common_types
!! \ingroup reconstruction
!----------------------------------------------------------------------------!
MODULE reconstruction_common
  USE common_types, &
       GetType_common => GetType, GetName_common => GetName, &
       GetRank_common => GetRank, GetNumProcs_common => GetNumProcs, &
       Initialized_common => Initialized, Info_common => Info, &
       Warning_common => Warning, Error_common => Error
  IMPLICIT NONE
  !--------------------------------------------------------------------------!
  PRIVATE
  ! exclude interface block from doxygen processing
  !> \cond InterfaceBlock
  INTERFACE GetType
     MODULE PROCEDURE GetOrder, GetType_common
  END INTERFACE
  INTERFACE GetName
     MODULE PROCEDURE GetOrderName, GetName_common
  END INTERFACE
  INTERFACE GetRank
     MODULE PROCEDURE GetReconstructionRank, GetRank_common
  END INTERFACE
  INTERFACE GetNumProcs
     MODULE PROCEDURE GetReconstructionNumProcs, GetNumProcs_common
  END INTERFACE
  INTERFACE Initialized
     MODULE PROCEDURE ReconstructionInitialized, Initialized_common
  END INTERFACE
  INTERFACE Info
     MODULE PROCEDURE ReconstructionInfo, Info_common
  END INTERFACE
  INTERFACE Warning
     MODULE PROCEDURE ReconstructionWarning, Warning_common
  END INTERFACE
  INTERFACE Error
     MODULE PROCEDURE ReconstructionError, Error_common
  END INTERFACE
  !> \endcond
  !--------------------------------------------------------------------------!
  !> Reconstruction data structure
  TYPE Reconstruction_TYP
     !> \name Variables
     TYPE(Common_TYP)  :: order                    !< constant, linear, ...
     TYPE(Common_TYP)  :: limiter                  !< limiter function
     LOGICAL           :: primcons                 !< true if primitive
     REAL              :: limiter_param            !< limiter parameter
     REAL, DIMENSION(:,:,:), &
          POINTER               :: xslopes,yslopes !< limited slopes
!!$ FIXME: compute reconstruciton points once at initialization
!!$        -> improves performance
!!$     REAL, DIMENSION(:,:,:,:), &                   ! positions with respect  !
!!$          POINTER               :: dx,dy           !   to cell bary centers  !
  END TYPE Reconstruction_TYP
  !--------------------------------------------------------------------------!
  !> \name Public Attributes
  INTEGER, PARAMETER :: PRIMITIVE    = 1           ! True  ! not type LOGICAL!
  INTEGER, PARAMETER :: CONSERVATIVE = 0           ! False ! because it cant !
                                                   ! be saved by netcdf      !
  !> \}
  !--------------------------------------------------------------------------!
  PUBLIC :: &
       ! types
       Reconstruction_TYP, &
       ! constants
       PRIMITIVE, CONSERVATIVE, &
       ! methods
       InitReconstruction, &
       CloseReconstruction, &
       PrimRecon, &
       GetType, &
       GetName, &
       GetRank, &
       GetNumProcs, &
       Initialized, &
       Info, &
       Warning, &
       Error
  !--------------------------------------------------------------------------!

CONTAINS

  !> \public
  SUBROUTINE InitReconstruction(this,rtype,rname,pc)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(Reconstruction_TYP) :: this
    INTEGER                  :: rtype
    CHARACTER(LEN=32)        :: rname
    INTEGER                  :: pc
    !------------------------------------------------------------------------!
    INTENT(IN)               :: rtype,rname,pc
    INTENT(INOUT)            :: this
    !------------------------------------------------------------------------!
    CALL InitCommon(this%order,rtype,rname)
    IF(pc.EQ.0) THEN
        this%primcons = .FALSE.
    ELSE
        this%primcons = .TRUE.
    END IF
  END SUBROUTINE InitReconstruction


  !> \public
  SUBROUTINE CloseReconstruction(this)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(Reconstruction_TYP), INTENT(INOUT) :: this
    !------------------------------------------------------------------------!
    CALL CloseCommon(this%order)
  END SUBROUTINE CloseReconstruction


  !> \public
  PURE FUNCTION GetOrder(this) RESULT(rt)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(Reconstruction_TYP), INTENT(IN) :: this
    INTEGER :: rt
    !------------------------------------------------------------------------!
!CDIR IEXPAND
    rt = GetType_common(this%order)
  END FUNCTION GetOrder


  PURE FUNCTION GetOrderName(this) RESULT(rn)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(Reconstruction_TYP), INTENT(IN) :: this
    CHARACTER(LEN=32) :: rn
    !------------------------------------------------------------------------!
!CDIR IEXPAND
    rn = GetName(this%order)
  END FUNCTION GetOrderName


  PURE FUNCTION PrimRecon(this) RESULT(pc)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(Reconstruction_TYP), INTENT(IN) :: this
    LOGICAL :: pc
    !------------------------------------------------------------------------!
!CDIR IEXPAND
    pc = this%primcons
  END FUNCTION PrimRecon
  

  PURE FUNCTION GetReconstructionRank(this) RESULT(r)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(Reconstruction_TYP), INTENT(IN) :: this
    INTEGER :: r
    !------------------------------------------------------------------------!
    r = GetRank_common(this%order)
  END FUNCTION GetReconstructionRank


  PURE FUNCTION GetReconstructionNumProcs(this) RESULT(p)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(Reconstruction_TYP), INTENT(IN) :: this
    INTEGER :: p
    !------------------------------------------------------------------------!
    p = GetNumProcs_common(this%order)
  END FUNCTION GetReconstructionNumProcs


  PURE FUNCTION ReconstructionInitialized(this) RESULT(i)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(Reconstruction_TYP), INTENT(IN) :: this
    LOGICAL :: i
    !------------------------------------------------------------------------!
    i = Initialized_common(this%order)
  END FUNCTION ReconstructionInitialized


  SUBROUTINE ReconstructionInfo(this,msg)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(Reconstruction_TYP), INTENT(IN) :: this
    CHARACTER(LEN=*),  INTENT(IN) :: msg
    !------------------------------------------------------------------------!
    CALL Info_common(this%order,msg)
  END SUBROUTINE ReconstructionInfo


  SUBROUTINE ReconstructionWarning(this,modproc,msg)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(Reconstruction_TYP), INTENT(IN) :: this
    CHARACTER(LEN=*),  INTENT(IN) :: modproc,msg
    !------------------------------------------------------------------------!
    CALL Warning_common(this%order,modproc,msg)
  END SUBROUTINE ReconstructionWarning


  SUBROUTINE ReconstructionError(this,modproc,msg)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(Reconstruction_TYP), INTENT(IN) :: this
    CHARACTER(LEN=*),  INTENT(IN) :: modproc,msg
    !------------------------------------------------------------------------!
    CALL Error_common(this%order,modproc,msg)
  END SUBROUTINE ReconstructionError


END MODULE reconstruction_common
