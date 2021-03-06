# ExtractSpecjbb2015.pm
package MMTests::ExtractSpecjbb2015;
use MMTests::SummariseSingleops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseSingleops);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractSpecjbb2015",
		_DataType    => DataTypes::DATA_ACTIONS,
		_PlotType    => "histogram",
		_SingleType  => 1,
		_ResultData  => [],
	};
	bless $self, $class;
	return $self;
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my $jvm_instance = -1;
	my $reading_tput = 0;
	my @jvm_instances;
	my $specjbb_bops;
	my $specjbb_bopsjvm;
	my $single_instance;
	my $pagesize = "base";

	if (! -e "$reportDir/$profile/$pagesize") {
		$pagesize = "transhuge";
	}
	if (! -e "$reportDir/$profile/$pagesize") {
		$pagesize = "default";
	}

	my @files = <$reportDir/$profile/$pagesize/result/specjbb2015-*/report-*/*.raw>;
	my $file = $files[0];
	if ($file eq "") {
		system("tar -C $reportDir/$profile/$pagesize -xf $reportDir/$profile/$pagesize/result.tar.gz");
		@files = <$reportDir/$profile/$pagesize/result/specjbb2015-*/report-*/*.raw>;
		$file = $files[0];
		die if ($file eq "");
	}

	open(INPUT, $file) || die("Failed to open $file\n");
	while (<INPUT>) {
		my $line = $_;

		if ($line =~ /jbb2015.result.metric.max-jOPS = ([0-9]+)/) {
			push @{$self->{_ResultData}}, [ "Max-JOPS", $1 ];
		}
		if ($line =~ /jbb2015.result.metric.critical-jOPS = ([0-9]+)/) {
			push @{$self->{_ResultData}}, [ "Critical-JOPS", $1 ];
		}
		if ($line =~ /jbb2015.result.SLA-([0-9]+)-jOPS = ([0-9]+)/) {
			push @{$self->{_ResultData}}, [ "SLA-$1us", $2 ];
		}
	}
	close INPUT;


}

1;
