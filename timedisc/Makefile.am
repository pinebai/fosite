#                                               -*- Automake -*-
# Process this file with automake --add-missing to produce a Makefile.
#############################################################################
#                                                                           #
# fosite - 2D hydrodynamical simulation program                             #
# configuration file: Makefile.am                                           #
#                                                                           #
# Copyright (C) 2012                                                        #
# Manuel Jung <mjung@astrophysik.uni-kiel.de>                               #
#                                                                           #
# This program is free software; you can redistribute it and/or modify      #
# it under the terms of the GNU General Public License as published by      #
# the Free Software Foundation; either version 2 of the License, or (at     #
# your option) any later version.                                           #
#                                                                           #
# This program is distributed in the hope that it will be useful, but       #
# WITHOUT ANY WARRANTY; without even the implied warranty of                #
# MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE, GOOD TITLE or        #
# NON INFRINGEMENT.  See the GNU General Public License for more            #
# details.                                                                  #
#                                                                           #
# You should have received a copy of the GNU General Public License         #
# along with this program; if not, write to the Free Software               #
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.                 #
#                                                                           #
#############################################################################

include ../common.am
SOURCES=timedisc_modeuler.f90 timedisc_dumka.f90 dumka_constants.f90 timedisc_rkfehlberg.f90 timedisc_generic.f90 timedisc_cashkarp.f90 timedisc_dormand_prince.f90 timedisc_multistep.f90 timedisc_ssprk.f90
OBJECTS = $(SOURCES:.f90=.o)

noinst_LIBRARIES = libtimedisc.a
libtimedisc_a_SOURCES = $(SOURCES)

$(DEPFILE) : $(SOURCES)
	$(AWK) -f $(MAKEDEPS) -v objfiles="$(OBJECTS)" $(addprefix $(srcdir)/,$(SOURCES)) > $@

-include $(DEPFILE)                                                                                                                                                                 
