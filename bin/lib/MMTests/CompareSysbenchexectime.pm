# CompareSysbenchexectime.pm
package MMTests::CompareSysbenchexectime;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareSysbenchexectime",
		_CompareOps  => [ "pndiff", "pndiff", "pndiff", "pndiff", "pndiff", "pndiff" ],
		_FieldLength => 12,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
