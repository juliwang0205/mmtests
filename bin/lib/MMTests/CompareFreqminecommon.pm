# CompareFreqminecommon.pm
package MMTests::CompareFreqminecommon;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareFreqminecommon",
		_FieldLength => 12,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
