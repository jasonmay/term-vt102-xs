use 5.012002;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Term::VT102::XS',
    VERSION_FROM      => 'lib/Term/VT102/XS.pm', # finds $VERSION
    PREREQ_PM         => {'Test::More' => '0'}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Term/VT102/XS.pm', # retrieve abstract from module
       AUTHOR         => 'jasonmay <jasonmay@local>') : ()),
    LIBS              => [''], # e.g., '-lm'
    DEFINE            => '', # e.g., '-DHAVE_SOMETHING'
    INC               => '-I.', # e.g., '-I. -I/usr/include/other'
	# Un-comment this if you add C files to link with later:
    # OBJECT            => '$(O_FILES)', # link all the C files too
);
