package civs_common;  # should be CIVS, or perhaps CIVS::Common

use strict;
use warnings;

# Export the package interface
BEGIN {
    use Exporter ();
    our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

    $VERSION     = 1.00;
    @ISA         = qw(Exporter);
    @EXPORT      = qw(&GetPrivateHostID &HTML_Header &CIVS_Header &Log &SecureNonce &fisher_yates_shuffle $home $thishost $civs_bin_path $civs_log $civs_url $local_debug $cr $lockfile $private_host_id);
}

# Package constructor
BEGIN {
	# This code is in a BEGIN block so that even compiler errors, as long
	# as they occur after this block, are caught.  They are recorded
	# in the CGILOG file.  Compile-time errors aren't timestamped,
	# unfortunately, but run-time ones are.  These are the errors
	# that used to be put in the global Apache error log.
	# It makes sense for every CGI script in CIVS to 
	# "use civs_common;" as its first action.
	use IO::Handle;
	use CGI::Carp qw(carpout);
	open(CGILOG, ">>@CIVSDATADIR@/cgi-log") or 
		die "Unable to open @CIVSDATADIR@/cgi-log: $!\n";
	autoflush CGILOG;
	carpout(\*CGILOG);
}

END {
	close CGILOG;
}

# Package imports
use CGI qw(:standard);
use POSIX qw(strftime);
use Digest::MD5 qw(md5_hex);
use Fcntl qw(:flock);
# use Time::HiRes qw(gettimeofday);

# Exported package globals
our $home = "@CIVSDATADIR@";
our $thishost = "@THISHOST@";
our $civs_bin_path = "@CIVSBINURL@";
our $civs_log = $home.'/log';
our $civs_url = "@CIVSURL@";
our $lockfile = $home.'/global_lock';
our $local_debug = 0;
our $cr = "\r\n";
our $private_host_id = '';

# Non-exported package globals
our $generated_header = 0;
our $private_host_id_file = $home.'/private_host_id';
our $nonce_seed_file = $home.'/nonce_seed';

sub GetPrivateHostID {
    if (!open(HOSTID, $private_host_id_file)) {
	&HTML_Header("Configuration error");
        print h1("Error"),
	      p("Unable to access the server's private key"),
	      end_html();
	exit 0;
    }
    $private_host_id=<HOSTID>;
    chomp $private_host_id;
    close(HOSTID);
}

sub HTML_Header {
    my $title = $_[0];
    if (!$generated_header) {
	print header(), start_html(-title => $title,
				   -style => {'src' => "@CIVSURL@/style.css"});
    }
}

sub CIVS_Header {
print "
<table border=0 width=100% cellspacing=0 cellpadding=7 class=\"banner\">
  <tr>
    <td width=100% valign=top nowrap>
    <h1>&nbsp;Condorcet Internet Voting Service</h1>
    </td>
    <td width=0% nowrap valign=top align=right><a href=\"$civs_url\">CIVS Home</a><br>
    <a href=\"$civs_url/civs_create.html\">Create new election</a><br>
    <a href=\"$civs_url/sec_priv.html\">About security and privacy</a>
    </td>
  </tr>
  <tr>
    <td width=100% valign=top nowrap colspan=2>
    <h2 align=center>$_[0]</h2>
    </td>
  </tr>
</table>
";
}

# Log the string provided
sub Log {
    my $now = strftime "%a %b %e %H:%M:%S %Y", localtime;
    open(CIVS_LOG, ">>$civs_log");
    print CIVS_LOG $now.' '.remote_addr().' '.$_[0].$cr;
    close(CIVS_LOG);
}

# SecureNonce() is an unpredictable nonce that cannot
# be predicted from the future state of the system (except
# for data derived from the nonce itself).
sub SecureNonce {
    GetPrivateHostID;
    open(LOCK, $lockfile) or die "Can't open global lock file $lockfile: $!\n";
    flock LOCK, &LOCK_EX;

    open(NONCEFILE, "<$nonce_seed_file") 
	    or die "Can't open nonce file for read: $!\n";
    my $seed = <NONCEFILE>;
    chomp $seed;
    close(NONCEFILE);
    my $ret = substr($seed, 0, 16);

    my $timeofday = `$home/gettimeofday`;
    $seed = md5_hex($private_host_id,$timeofday,$seed);

    open(NONCEFILE, ">$nonce_seed_file")
	or die "Can't open nonce file for write: $!\n";
    print NONCEFILE $seed.$cr;
    close(NONCEFILE);
    flock LOCK, &LOCK_UN;
    close(LOCK);
    return $ret;
}

# From the Perl Cookbook, p. 121
# Generate a random permutation of @array in place.
sub fisher_yates_shuffle {
    my $array = shift;
    my $i;
    for ($i = @$array; --$i; ) {
	my $j = int rand ($i+1);
	next if $i == $j;
	@$array[$i,$j] = @$array[$j,$i];
    }
}

1; # ok!
