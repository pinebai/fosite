!#############################################################################
!#                                                                           #
!# fosite - 2D hydrodynamical simulation program                             #
!# module: geometry_tanpolar.f90                                             #
!#                                                                           #
!# Copyright (C) 2008 Tobias Illenseer <tillense@astrophysik.uni-kiel.de>    #
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
!> \author Tobias Illenseer
!!
!! \brief define properties of a tangential 2D polar mesh
!!
!! dimensionless radial coordinate rho (with 0 < rho < +pi/2) according to:
!!    x = r0 * tan(rho) * cos(phi)
!!    y = r0 * tan(rho) * sin(phi)
!!
!! \extends geometry_cartesian
!! \ingroup geometry
!----------------------------------------------------------------------------!
MODULE geometry_tanpolar
  USE geometry_cartesian
  IMPLICIT NONE
  !--------------------------------------------------------------------------!
  ! exclude interface block from doxygen processing
  !> \cond InterfaceBlock
  INTERFACE Convert2Cartesian_tanpolar
     MODULE PROCEDURE Tanpolar2Cartesian_coords, Tanpolar2Cartesian_vectors
  END INTERFACE
  INTERFACE Convert2Curvilinear_tanpolar
     MODULE PROCEDURE Cartesian2Tanpolar_coords, Cartesian2Tanpolar_vectors
  END INTERFACE
  !> \endcond
  PRIVATE
  CHARACTER(LEN=32), PARAMETER :: geometry_name = "tanpolar"
  !--------------------------------------------------------------------------!
  PUBLIC :: &
       InitGeometry_tanpolar, &
       ScaleFactors_tanpolar, &
       Radius_tanpolar, &
       PositionVector_tanpolar, &
       Convert2Cartesian_tanpolar, &
       Convert2Curvilinear_tanpolar, &
       Tanpolar2Cartesian_coords, &
       Tanpolar2Cartesian_vectors, &
       Cartesian2Tanpolar_coords, &
       Cartesian2Tanpolar_vectors
  !--------------------------------------------------------------------------!

CONTAINS

  SUBROUTINE InitGeometry_tanpolar(this,gt,gp)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    TYPE(Geometry_TYP), INTENT(INOUT) :: this
    INTEGER, INTENT(IN) :: gt
    REAL, INTENT(IN) :: gp
    !------------------------------------------------------------------------!
    CALL InitGeometry(this,gt,geometry_name)
    CALL SetScale(this,gp)
  END SUBROUTINE InitGeometry_tanpolar
    

  ELEMENTAL SUBROUTINE ScaleFactors_tanpolar(gp,rho,hrho,hphi,hz)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    REAL, INTENT(IN)  :: gp,rho
    REAL, INTENT(OUT) :: hrho,hphi,hz
    !------------------------------------------------------------------------!
    hrho = gp/COS(rho)**2
    hphi = Radius_tanpolar(gp,rho)
    hz   = 1.
  END SUBROUTINE ScaleFactors_tanpolar


  ELEMENTAL FUNCTION Radius_tanpolar(gp,rho) RESULT(radius)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    REAL, INTENT(IN)  :: gp,rho
    REAL :: radius
    !------------------------------------------------------------------------!
    radius = gp * TAN(rho)
  END FUNCTION Radius_tanpolar


  ELEMENTAL SUBROUTINE PositionVector_tanpolar(gp,rho,rx,ry)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    REAL, INTENT(IN)  :: gp,rho
    REAL, INTENT(OUT) :: rx,ry
    !------------------------------------------------------------------------!
    rx = Radius_tanpolar(gp,rho)
    ry = 0.0
  END SUBROUTINE PositionVector_tanpolar


  ! coordinate transformations
  ELEMENTAL SUBROUTINE Tanpolar2Cartesian_coords(gp,rho,phi,x,y)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    REAL, INTENT(IN)  :: gp,rho,phi
    REAL, INTENT(OUT) :: x,y
    !------------------------------------------------------------------------!
    REAL :: r
    !------------------------------------------------------------------------!
    r = gp*TAN(rho)
    x = r*COS(phi)
    y = r*SIN(phi)
  END SUBROUTINE Tanpolar2Cartesian_coords

  ELEMENTAL SUBROUTINE Cartesian2Tanpolar_coords(gp,x,y,rho,phi)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    REAL, INTENT(IN)  :: gp,x,y
    REAL, INTENT(OUT) :: rho,phi
    !------------------------------------------------------------------------!
    REAL :: x1,y1
    !------------------------------------------------------------------------!
    x1 = x/gp
    y1 = y/gp
    rho = ATAN(SQRT(x1*x1+y1*y1))
    phi = ATAN2(y,x)
    IF(phi.LT.0.0) THEN
        phi = phi + 2.0*PI
    END IF
  END SUBROUTINE Cartesian2Tanpolar_coords


  ! vector transformations
  ELEMENTAL SUBROUTINE Tanpolar2Cartesian_vectors(gp,phi,vrho,vphi,vx,vy)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    REAL, INTENT(IN)  :: gp,phi,vrho,vphi
    REAL, INTENT(OUT) :: vx,vy
    !------------------------------------------------------------------------!
    vx = vrho * COS(phi) - vphi * SIN(phi)
    vy = vrho * SIN(phi) + vphi * COS(phi)
  END SUBROUTINE Tanpolar2Cartesian_vectors
  
  ELEMENTAL SUBROUTINE Cartesian2Tanpolar_vectors(gp,phi,vx,vy,vrho,vphi)
    IMPLICIT NONE
    !------------------------------------------------------------------------!
    REAL, INTENT(IN)  :: gp,phi,vx,vy
    REAL, INTENT(OUT) :: vrho,vphi
    !------------------------------------------------------------------------!
    vrho = vx * COS(phi) + vy * SIN(phi)
    vphi = -vx * SIN(phi) + vy * COS(phi)
  END SUBROUTINE Cartesian2Tanpolar_vectors
  
END MODULE geometry_tanpolar
