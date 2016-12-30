#include "types.h"
#include "dns_const.h"

SUBROUTINE FI_CHEM(chemistry, nx,ny,nz, is, s, source)

  USE DNS_TYPES,  ONLY : term_structure
  USE DNS_GLOBAL, ONLY : ycoor_i
  USE DNS_GLOBAL, ONLY : g

  IMPLICIT NONE

  TYPE(term_structure),         INTENT(IN)  :: chemistry
  TINTEGER,                     INTENT(IN)  :: nx,ny,nz, is
  TREAL, DIMENSION(nx*ny*nz,*), INTENT(IN)  :: s
  TREAL, DIMENSION(nx*ny*nz),   INTENT(OUT) :: source

! -----------------------------------------------------------------------
  TREAL xi, dummy, thickness_inv, ycenter
  TINTEGER i,j,k

!########################################################################
  SELECT CASE( chemistry%type )

  CASE( EQNS_CHEM_QUADRATIC )
     source = chemistry%parameters(is) * s(:,2) *s(:,3)

  CASE( EQNS_CHEM_LAYEREDRELAXATION )
     ycenter = g(2)%nodes(1) + g(2)%scale *ycoor_i(is) + chemistry%parameters(2)
     thickness_inv = C_1_R /chemistry%parameters(3)
     DO i=1,nx
        DO k=1,nz
           DO j=1,ny
              xi = (g(2)%nodes(j)-ycenter) /chemistry%parameters(3)
              source(i+(j-1)*nx+(k-1)*nx*ny) = C_05_R *( C_1_R +TANH(xi) ) !strength constant
           ENDDO
        ENDDO
     ENDDO
     
     dummy  =-C_1_R /chemistry%parameters(1)
     source = dummy *source*s(:,is)

  CASE( EQNS_CHEM_OZONE )
! 2. species is O3
! 3. species is NO
! 4. species is NO2
! calculate the reaction constant
     source = chemistry%parameters(2) *EXP(chemistry%parameters(3)*s(:,1))
     
     source = chemistry%parameters(1) *s(:,4) - source *s(:,2) *s(:,3)
     IF ( is .EQ. 4 ) source =-source
     
  END SELECT
  
  RETURN
END SUBROUTINE FI_CHEM
