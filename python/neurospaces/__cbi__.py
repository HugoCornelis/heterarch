"""
@file __cbi__.py

This file provides data for a packages integration
into the CBI architecture.
"""

__author__ = "Mando Rodriguez"
__copyright__ = "Copyright 2011, The Neurospaces Project"
__credits__ = ["Hugo Cornelis"]
__license__ = "GPL"
__version__ = "0.1"
__maintainer__ = "Hugo Cornelis"
__email__ = "hugo dot cornelis at gmail dot com"
__status__ = "Development"
__url__ = "http://www.neurospaces.org/"
__description__ = """
This is the root module for Neurospaces.  Neurospaces is composed of several
components for reading and storing computational models, solvers, experimental protocols,
and GUI interfaces. The root 'neurospaces' package helps to determine which versions of
packages are installed and performs updates, removal, and installation of needed
packages to run a simulation. 
"""
__download_url__ = "http://www.neurospaces.org/"

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
