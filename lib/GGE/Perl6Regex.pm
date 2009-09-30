use v6;
use GGE::Match;

class GGE::Perl6Regex {
    has $!pattern;

    method new($pattern) {
        return self.bless(*, :$pattern);
    }

    submethod p($pos, $substr) {
        $!pattern.substr($pos, $substr.chars) eq $substr;
    }

    sub matches($string, $pos, $pattern) {
        $pattern eq '.'
            ?? $pos < $string.chars
            !! $string.substr($pos, $pattern.chars) eq $pattern;
    }

    submethod parse-backtracking-modifiers($rxpos is rw, $term is rw) {
        if self.p($rxpos, ':?') {
            $term<ratchet> = False;
            $term<type> = 'eager';
            $rxpos += 2;
        }
        elsif self.p($rxpos, ':!') {
            $term<ratchet> = False;
            $rxpos += 2;
        }
        elsif self.p($rxpos, '?') {
            $term<ratchet> = False;
            $term<type> = 'eager';
            ++$rxpos;
        }
        elsif self.p($rxpos, '!') {
            $term<ratchet> = False;
            ++$rxpos;
        }
        elsif self.p($rxpos, ':') {
            $term<ratchet> = True;
            ++$rxpos;
        }
    }

    method postcircumfix:<( )>($target) {
        my $rxpos = 0;
        my $ratchet = False;
        my @terms;
        while $rxpos < $!pattern.chars {
            my $term;
            if self.p($rxpos, ':ratchet') {
                $ratchet = True;
                $rxpos += 8;
                next;
            }
            elsif self.p($rxpos, '**') {
                $term = { :type<greedy>, :$ratchet, :expr(@terms.pop) };
                $rxpos += 2;
                self.parse-backtracking-modifiers($rxpos, $term);
                my $brackets = False;
                if self.p($rxpos, '{') {
                    $brackets = True;
                    ++$rxpos;
                }
                $term<min> = $term<max> = $!pattern.substr($rxpos, 1);
                $rxpos++;
                if self.p($rxpos, '..') {
                    $rxpos += 2;
                    $term<max> = $!pattern.substr($rxpos, 1);
                    ++$rxpos;
                }
                if $brackets {
                    die 'No "}" found'
                        unless self.p($rxpos, '}');
                    $rxpos += 1;
                }
            }
            elsif (my $op = $!pattern.substr($rxpos, 1)) eq '*'|'+'|'?' {
                $term = { :type<greedy>, :min(0), :max(Inf), :$ratchet,
                          :expr(@terms.pop) };
                if $op eq '+' {
                    $term<min> = 1;
                }
                elsif $op eq '?' {
                    $term<max> = 1;
                }
                ++$rxpos;
                self.parse-backtracking-modifiers($rxpos, $term);
            }
            elsif self.p($rxpos, ' ') {
                ++$rxpos;
                next;
            }
            else {
                $term = $!pattern.substr($rxpos, 1);
                $rxpos++;
            }
            push @terms, $term;
        }
        for ^$target.chars -> $from {
            my $to = $from;
            my $termindex = 0;
            my $backtracking = False;
            while 0 <= $termindex < +@terms {
                given @terms[$termindex] {
                    when Str {
                        if matches($target, $to, $_) {
                            $to += .chars;
                            $termindex++;
                        }
                        else {
                            $backtracking = True;
                            $termindex--;
                            next;
                        }
                    }
                    unless $backtracking {
                        .<reps> = 0;
                    }
                    my $l = .<expr>.chars;
                    # RAKUDO: Must do this because there are no labels
                    my $failed = False;
                    while .<reps> < .<min> && !$failed {
                        if matches($target, $to, .<expr>) {
                            $to += $l;
                            .<reps>++;
                        }
                        else {
                            .<reps> = 0;
                            $failed = True;
                        }
                    }
                    if $failed {
                        $backtracking = True;
                        $termindex--;
                        next;
                    }
                    if $backtracking {
                        if .<ratchet> {
                            $termindex = -1;
                            last;
                        }
                        elsif .<type> eq 'greedy' {
                            # we were too greedy, so try to back down one
                            if .<reps> > .<min> {
                                $to -= $l;
                                .<reps>--;
                            }
                            else {
                                $termindex--;
                                next;
                            }
                        }
                        else { # we were too eager, so try to add one
                            if .<reps> < .<max>
                               && matches($target, $to, .<expr>) {
                                $to += $l;
                                .<reps>++;
                            }
                            else {
                                $termindex--;
                                next;
                            }
                        }
                        $backtracking = False;
                    }
                    elsif .<type> eq 'greedy' {
                        while .<reps> < .<max>
                              && matches($target, $to, .<expr>) {
                            $to += $l;
                            .<reps>++;
                        }
                    }
                    $termindex++;
                }
            }
            if $termindex == +@terms {
                return GGE::Match.new(:$target, :$from, :$to);
            }
        }
        return GGE::Match.new(:$target, :from(0), :to(-2));
    }
}
