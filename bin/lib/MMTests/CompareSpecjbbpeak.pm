# CompareSpecjbbpeak.pm
package MMTests::CompareSpecjbbpeak;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareSpecjbbpeak",
		_FieldLength => 15,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
