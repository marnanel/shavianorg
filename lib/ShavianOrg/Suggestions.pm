package ShavianOrg::Suggestions;

use strict;
use warnings;

use ShavianOrg::Database;
use Encode;

sub new {
  my ($class) = @_;

  my %result = (
    db => new ShavianOrg::Database(),
  );

  my $prefill = $result{'db'}->fetch('Prefill_magic', 4);
  $prefill = Encode::decode('UTF-8', $prefill);

  my @prefill = $prefill =~ /\{\{Prefill\|(.*?)\|(.*?)\|(.*?)\|(.*?)\}\}/gi;

  my @rules;

  while (@prefill) {
    my $latnsub = shift @prefill;
    my $latnadd = shift @prefill;
    my $shawend = shift @prefill;
    my $shawadd = shift @prefill;
    push @rules, {
      shawadd => $shawadd,
      shawend => $shawend,
      latnadd => $latnadd,
      latnsub => $latnsub,
    };
  }

  $result{'rules'} = \@rules;

  return bless \%result, $class;
}

sub _handle_inflection {
  my ($self, $latn) = @_;

  for my $rule (@{$self->{'rules'}}) {
    my $temp = $latn;

    next unless $temp =~ s/($rule->{latnsub})$//i;
    $temp .= $rule->{'latnadd'};
    my $spelling = $self->{'db'}->fetch_spelling($temp);
    next unless $spelling;

    if ($rule->{'shawend'}) {
      next if index($rule->{'shawend'},
        substr($spelling, -1)) == -1;
    }

    $spelling .= $rule->{'shawadd'};

    return [$spelling, $temp];
  }

  return undef;
}

sub _handle_compounds {
  my ($self, $latn) = @_;

  for (my $i=1; $i<length($latn); $i++) {
    my $left = substr($latn, 0, $i);
    my $right = substr($latn, $i);

    my $left_spelling = $self->{db}->fetch_spelling($left);
    my $right_spelling = $self->{db}->fetch_spelling($right);
    if ($left_spelling && $right_spelling) {

      return [$left_spelling.$right_spelling,
      "$left+$right"];
    }
  }

  return undef;
}

sub handle {
  my ($self, $latn) = @_;

  for my $handler (
    \&_handle_inflection,
    \&_handle_compounds,
  ) {
    my $result = $handler->($self, $latn);

    return $result if $result;
  }

  return undef;
}

1;

