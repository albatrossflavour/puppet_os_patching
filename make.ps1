<#
.SYNOPSIS
  Run PDQTest targets
.DESCRIPTION
  See the instructions at https://github.com/declarativesystems/pdqtest/blob/master/doc/running_tests.md
.EXAMPLE
  .\make.ps1 - Run the default testing target
.EXAMPLE
  .\make.ps1 XXX - run the XXX target
.PARAMETER target
  Test suite to run
#>
param(
    $target = "all"
)
# *File originally created by PDQTest*

$gfl = "Gemfile.local"
$gfp = "Gemfile.project"

# Relink Gemfile.local
# https://github.com/declarativesystems/pdqtest/blob/master/doc/pdk.md#why-are-the-launch-scripts-essentialhow-does-the-pdqtest-gem-load-itself
function Install-GemfileLocal {
  # on windows, symlinks dont work on vagrant fileshares, so just copy the 
  # file if needed
  if (Test-Path $gfl) {
    $gflMd5 = (Get-FileHash -Path $gfl -Algorithm MD5).Hash
    $gfpMd5 = (Get-FileHash -Path $gfp -Algorithm MD5).Hash
    if ($gflMd5 -eq $gfpMd5) {
      # OK - ready to launch
    } else {
      write-error "$($gfl) different content to $($gfp)! Move it out the way or move the content to $($gfp)"
    }
  } else {
    write-host "[(-_-)zzz] Copying $($gfp) to $($gfl) and running pdk bundle..."
    copy $gfp $gfl
    pdk bundle install
  }
}


switch ($target) {
    "all" {
        cd .pdqtest; bundle exec pdqtest all; cd ..
    }
    "fast" {
        cd .pdqtest; bundle exec pdqtest fast; cd ..
    }
    "acceptance" {
        cd .pdqtest; bundle exec pdqtest acceptance; cd ..
    }
    "shell" {
        cd .pdqtest; bundle exec pdqtest --keep-container acceptance; cd ..
    }
    "shellnopuppet" {
        cd .pdqtest; bundle exec pdqtest shell; cd ..
    }
    "setup" {
        cd .pdqtest; bundle exec pdqtest setup; cd ..
    }
    "logical" {
        cd .pdqtest; bundle exec pdqtest logical; cd ..
        cd .pdqtest ; bundle exec "cd ..; puppet strings"; cd ..
    }
    "docs" {
        cd .pdqtest ; bundle exec "cd ..; puppet strings generate --format markdown"; cd ..
    }
    "Gemfile.local" {
        echo "[(-_-)zzz] *copying* Gemfile.project to Gemfile.local and running pdk bundle..."
        Install-GemfileLocal
        .\make.ps1 pdkbundle
    }
    "pdqtestbundle" {
        cd .pdqtest ; bundle install; cd ..
    }
    "pdkbundle" {
        pdk bundle install
    }
    "clean" {
        Remove-Item -ErrorAction SilentlyContinue -Confirm:$false -Recurse -force pkg
        Remove-Item -ErrorAction SilentlyContinue -Confirm:$false -Recurse -force spec/fixtures/modules
    }
    default {
        Write-Error "No such target: $($target)"
    }
}
