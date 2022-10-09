use ExtUtils::MakeMaker;

WriteMakefile(
    NAME	 => 'AptPkg',
    VERSION_FROM => 'AptPkg.pm',
    CC		 => 'c++',
    LD		 => 'c++',
    OBJECT	 => '$(O_FILES)',
    LIBS	 => ['-lapt-pkg'],
    XSOPT	 => '-C++',
    depend	 => { Makefile => 'AptPkg.pm' },  # for VERSION
    clean	 => { FILES => 't/cache/var/*.bin' },
);
