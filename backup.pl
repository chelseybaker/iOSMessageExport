#!/usr/bin/env perl

use strict;
use warnings;
use v5.10;

use Getopt::Long;

use iOSSMSBackup;
my $directory;
my $css;
my $export;
GetOptions("directory_path=s" => \$directory, "export_path=s" => \$export, "css=s" => \$css);

my $ios_backup = iOSSMSBackup->new({
   backup_directory => $directory,
   export_directory => $export,
   css => $css
});
if ($ios_backup){
    $ios_backup->export_messages();
}else{
    print "no backup";
}
