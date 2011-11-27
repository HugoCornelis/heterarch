"""
@file __cbi__.py

This file provides data for a packages integration
into the CBI architecture.
"""

__author__ = "Mando Rodriguez"
__copyright__ = "Copyright 2010, The GENESIS Project"
__credits__ = ["Hugo Cornelis", "Dave Beeman"]
__license__ = "GPL"
__version__ = "0.1"
__maintainer__ = "Mando Rodriguez"
__email__ = "rodrigueza14 at uthscsa dot edu"
__status__ = "Development"
__url__ = "http://genesis-sim.org"
__description__ = """
This is the root management module for GENESIS. GENESIS is composed of several
sub packages for reading and storing models, solvers, experimental protocols,
and GUI interfaces. The root 'neurospaces' package helps to determine which versions of
packages are installed and performs updates, removal, and installation of needed
packages to run a simulation. 
"""
__download_url__ = "http://repo-genesis3.cbi.utsa.edu"

class PackageInfo:
        
    def GetRevisionInfo(self):
# $Format: "        return \"${monotone_id}\""$
        return "86b7c29a1f505c457e8b169831bc532c4a5426b6"

    def GetName(self):

        return "neurospaces"

    def GetVersion(self):
# $Format: "        return \"${major}.${minor}.${micro}-${label}\""$
        return "0.0.0-alpha"

    def GetDependencies(self):
        """!
        @brief Provides a list of other CBI dependencies needed.
        """
        dependencies = ['model-container', 'heccer', 'experiment',
                        'chemesis3',]
        
        return dependencies
