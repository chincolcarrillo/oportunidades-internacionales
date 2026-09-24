source('scripts/load.R')
testthat::test_dir('tests/testthat',reporter='summary',stop_on_failure=TRUE,load_package='none')
