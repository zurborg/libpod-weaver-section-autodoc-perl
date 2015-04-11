use strictures 2;

package t::lib;

use Pod::Weaver;
use Pod::Weaver::Section::AutoDoc;
use App::podweaver;
use File::Slurp qw(read_file write_file);
use Exporter qw(import);

BEGIN {
    chdir('t');
}

our @EXPORT = qw(load_doc);

sub pm2pod {
    my ($file, $weaver) = @_;
    
    $weaver //= Pod::Weaver->new_from_config;
    
    App::podweaver->weave_file(
        filename => $file,
        weaver => $weaver,
        no_backup => 0,
        new => 1
    );
    open(my $fh, '<', "$file.new") or die "cannot open file $file.new: $!\n";
    my $pod;
    while (my $line = <$fh>) {
        last if $line =~ m{^__END__\s*$}s;
    }
    while (my $line = <$fh>) {
        $pod .= $line;
    }
    close $fh;
    return $pod;
}

sub prepare {
    my $module = shift;
    $module =~ s{::}{/}g;
    $module = "lib/$module";
    my $pod = pm2pod("$module.pm");
    write_file("$module.pod", $pod);
}

sub load_doc {
    my $module = shift;
    $module =~ s{::}{/}g;
    $module = "lib/$module";
    my $pod = pm2pod("$module.pm");
    my $cmp = read_file("$module.pod");
    return ($pod, $cmp);
}

1;
