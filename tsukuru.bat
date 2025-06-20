                @echo off
                set jarpath="bin/tsukuru.jar"
                set pattern="%1"
                shift
                :loop
                  if "%1" == "" goto :allprocessed
                  set files=%1 %2 %3 %4 %5 %6 %7 %8 %9
                  java -jar %jarpath% %pattern% %files% 2>&1
                  set exitcode=%ERRORLEVEL%
                  for %%i in (0 1 2 3 4 5 6 7 8) do shift
                goto loop

                :allprocessed