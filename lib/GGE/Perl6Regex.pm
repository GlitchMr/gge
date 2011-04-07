use v6;
use GGE::Match;
use GGE::Exp;
use GGE::OPTable;

use MONKEY_TYPING;

class GGE::Exp::WS is GGE::Exp::Subrule {
    method contents() {}
}

class GGE::Perl6Regex {
    has GGE::Exp $.exp;
    has Callable $!binary;

    my &unescape = -> @codes { join '', map { chr(:16($_)) }, @codes };
    my $h-whitespace = unescape <0009 0020 00a0 1680 180e 2000 2001 2002 2003
                                 2004 2005 2006 2007 2008 2008 2009 200a 202f
                                 205f 3000>;
    my $v-whitespace = unescape <000a 000b 000c 000d 0085 2028 2029>;
    my %esclist =
        'h' => $h-whitespace,
        'v' => $v-whitespace,
        'e' => "\c[27]", # RAKUDO: No "\e". [RT #75244]
        'f' => "\f",
        'r' => "\r",
        't' => "\t",
    ;

    my $optable = GGE::OPTable.new();
    $optable.newtok('term:',     :precedence('='),
                    :nows, :parsed(&GGE::Perl6Regex::parse_term));
    $optable.newtok('term:#',    :equiv<term:>,
                    :nows, :parsed(&GGE::Perl6Regex::parse_term_ws));
    $optable.newtok('term:\\',   :equiv<term:>,
                    :nows, :parsed(&GGE::Perl6Regex::parse_term_backslash));
    $optable.newtok('term:^',    :equiv<term:>,
                    :nows, :match(GGE::Exp::Anchor));
    $optable.newtok('term:^^',   :equiv<term:>,
                    :nows, :match(GGE::Exp::Anchor));
    $optable.newtok('term:$$',   :equiv<term:>,
                    :nows, :match(GGE::Exp::Anchor));
    $optable.newtok('term:<<',   :equiv<term:>,
                    :nows, :match(GGE::Exp::Anchor));
    $optable.newtok('term:>>',   :equiv<term:>,
                    :nows, :match(GGE::Exp::Anchor));
    $optable.newtok('term:<?>',  :equiv<term:>,
                    :nows, :match(GGE::Exp::Anchor));
    $optable.newtok('term:<!>',  :equiv<term:>,
                    :nows, :match(GGE::Exp::Anchor));
    $optable.newtok('term:.',    :equiv<term:>,
                    :nows, :match(GGE::Exp::CCShortcut));
    $optable.newtok('term:\\d',  :equiv<term:>,
                    :nows, :match(GGE::Exp::CCShortcut));
    $optable.newtok('term:\\D',  :equiv<term:>,
                    :nows, :match(GGE::Exp::CCShortcut));
    $optable.newtok('term:\\s',  :equiv<term:>,
                    :nows, :match(GGE::Exp::CCShortcut));
    $optable.newtok('term:\\S',  :equiv<term:>,
                    :nows, :match(GGE::Exp::CCShortcut));
    $optable.newtok('term:\\w',  :equiv<term:>,
                    :nows, :match(GGE::Exp::CCShortcut));
    $optable.newtok('term:\\W',  :equiv<term:>,
                    :nows, :match(GGE::Exp::CCShortcut));
    $optable.newtok('term:\\N',  :equiv<term:>,
                    :nows, :match(GGE::Exp::CCShortcut));
    $optable.newtok('term:\\n',  :equiv<term:>,
                    :nows, :match(GGE::Exp::Newline));
    $optable.newtok('term:$',    :equiv<term:>,
                    :nows, :parsed(&GGE::Perl6Regex::parse_dollar));
    $optable.newtok('term:<',    :equiv<term:>,
                    :nows, :parsed(&GGE::Perl6Regex::parse_subrule));
    $optable.newtok('term:<.',   :equiv<term:>,
                    :nows, :parsed(&GGE::Perl6Regex::parse_subrule));
    $optable.newtok('term:<?',   :equiv<term:>,
                    :nows, :parsed(&GGE::Perl6Regex::parse_subrule));
    $optable.newtok('term:<!',   :equiv<term:>,
                    :nows, :parsed(&GGE::Perl6Regex::parse_subrule));
    $optable.newtok('term:<[',   :equiv<term:>,
                    :nows, :parsed(&GGE::Perl6Regex::parse_enumcharclass));
    $optable.newtok('term:<+',   :equiv<term:>,
                    :nows, :parsed(&GGE::Perl6Regex::parse_enumcharclass));
    $optable.newtok('term:<-',   :equiv<term:>,
                    :nows, :parsed(&GGE::Perl6Regex::parse_enumcharclass));
    $optable.newtok("term:'",    :equiv<term:>,
                    :nows, :parsed(&GGE::Perl6Regex::parse_quoted_literal));
    $optable.newtok('term:::',   :equiv<term:>,
                    :nows, :match(GGE::Exp::Cut));
    $optable.newtok('term::::',  :equiv<term:>,
                    :nows, :match(GGE::Exp::Cut));
    $optable.newtok('term:<commit>', :equiv<term:>,
                    :nows, :match(GGE::Exp::Cut));
    $optable.newtok('circumfix:[ ]', :equiv<term:>,
                    :nows, :match(GGE::Exp::Group));
    $optable.newtok('circumfix:( )', :equiv<term:>,
                    :nows, :match(GGE::Exp::CGroup));
    $optable.newtok('postfix:*', :looser<term:>,
                    :parsed(&GGE::Perl6Regex::parse_quant));
    $optable.newtok('postfix:+', :equiv<postfix:*>,
                    :parsed(&GGE::Perl6Regex::parse_quant));
    $optable.newtok('postfix:?', :equiv<postfix:*>,
                    :parsed(&GGE::Perl6Regex::parse_quant));
    $optable.newtok('postfix::', :equiv<postfix:*>,
                    :parsed(&GGE::Perl6Regex::parse_quant));
    $optable.newtok('postfix:**', :equiv<postfix:*>,
                    :parsed(&GGE::Perl6Regex::parse_quant));
    $optable.newtok('infix:',    :looser<postfix:*>, :assoc<list>,
                    :nows, :match(GGE::Exp::Concat));
    $optable.newtok('infix:&',   :looser<infix:>,
                    :nows, :match(GGE::Exp::Conj));
    $optable.newtok('infix:|',   :looser<infix:&>,
                    :nows, :match(GGE::Exp::Alt));
    $optable.newtok('prefix:|',  :equiv<infix:|>,
                    :nows, :match(GGE::Exp::Alt));
    $optable.newtok('infix:=',   :tighter<infix:>, :assoc<right>,
                    :match(GGE::Exp::Alias));
    $optable.newtok('prefix::',  :looser<infix:|>,
                    :parsed(&GGE::Perl6Regex::parse_modifier));

    method new($pattern, :$debug) {
        # RAKUDO: Cannot call a sub named 'regex' without the '&' [perl #72438]
        my $match = &regex($pattern);
        die 'Perl6Regex rule error: can not parse expression'
            if $match.to < $pattern.chars;
        my $exp = perl6exp($match<expr>, { lexscope => {} });
        my $binary = $exp.compile(:$debug);
        return self.bless(*, :$exp, :$binary);
    }

    # Why the double parens in the parameter list? Apparently, the
    # postcircumfix:<( )> method gets called with a Capture, so we have to
    # unpack that.
    method postcircumfix:<( )>( ($target, :$debug) ) {
        $!binary($target, :$debug);
    }

    sub regex($mob, :$tighter, :$stop) {
        return $optable.parse($mob, :$tighter, :$stop);
    }

    our sub parse_term($mob) {
        if $mob.target.substr($mob.to, 1) ~~ /\s/ {
            return parse_term_ws($mob);
        }
        my $m = GGE::Exp::Literal.new($mob);
        my $pos = $mob.to;
        my $target = $m.target;
        while $target.substr($pos, 1) ~~ /\w/ {
            ++$pos;
        }
        if $pos - $mob.to > 1 {
            --$pos;
        }
        if $pos == $mob.to {
            return $m;  # i.e. fail
        }
        $m.to = $pos;
        $m;
    }

    our sub parse_term_ws($mob) {
        my $m = GGE::Exp::WS.new($mob);
        $m.to = $mob.to;
        $m.to++ while $m.target.substr($m.to, 1) ~~ /\s/;
        if (~$m.target).substr($m.to, 1) eq '#' {
            my $delim = "\n";
            $m.to = defined (~$m.target).index($delim, $m.to)
                    ?? (~$m.target).index($delim, $m.to) + 1
                    !! (~$m.target).chars;
        }
        $m;
    }

    sub p6escapes($mob, :$pos! is copy) {
        my $m = GGE::Match.new($mob);
        my $target = ~$m.target;
        my $backchar = $target.substr($pos + 1, 1);
        $pos += 2;
        my $isbracketed = $target.substr($pos, 1) eq '[';
        my $base = $backchar eq 'c'|'C' ?? 10
                !! $backchar eq 'o'|'O' ?? 8
                !!                         16;
        my $literal = '';
        $pos += $isbracketed;
        my &readnum = {
            my $decnum = 0;
            while $pos < $target.chars
                  && defined(
                       my $digit = '0123456789abcdef0123456789ABCDEF'\
                          .index($target.substr($pos, 1))) {
                $digit %= 16;
                $decnum *= $base;
                $decnum += $digit;
                ++$pos;
            }
            $literal ~= chr($decnum);
        };
        if $isbracketed {
            repeat {
                ++$pos while $pos < $target.chars
                             && $target.substr($pos, 1) ~~ /\s/;
                readnum();
                ++$pos while $pos < $target.chars
                             && $target.substr($pos, 1) ~~ /\s/;
            } while $target.substr($pos, 1) eq ',' && ++$pos;
            die "Missing close bracket for \\x[...], \\o[...], or \\c[...]"
                if $target.substr($pos, 1) ne ']';
        }
        else {
            readnum();
        }
        $pos += $isbracketed;
        $m.make($literal);
        $m.to = $pos - 1;
        $m;
    }

    our sub parse_term_backslash($mob) {
        my $backchar = substr($mob.target, $mob.to, 1);
        my $isnegated = $backchar eq $backchar.uc;
        $backchar .= lc;
        if $backchar eq 'x'|'c'|'o' {
            my $escapes = p6escapes($mob, :pos($mob.to - 1));
            die 'Unable to parse \x, \c, or \o value'
                unless $escapes;
            # XXX: Can optimize here by special-casing on 1-elem charlist.
            #      PGE does this.
            my GGE::Exp $m = $isnegated ?? GGE::Exp::EnumCharList.new($mob)
                                        !! GGE::Exp::Literal.new($mob);
            $m<isnegated> = $isnegated;
            $m.make($escapes.ast);
            $m.to = $escapes.to + 1;
            return $m;
        }
        elsif %esclist.exists($backchar) {
            my $charlist = %esclist{$backchar};
            my GGE::Exp $m = GGE::Exp::EnumCharList.new($mob);
            $m<isnegated> = $isnegated;
            $m.make($charlist);
            $m.to = $mob.to + 1;
            return $m;
        }
        elsif $backchar ~~ /\w/ {
            die 'Alphanumeric metacharacters are reserved';
        }

        my $m = GGE::Exp::Literal.new($mob);
        $m.make($backchar);
        $m.to = $mob.to + 1;
        return $m;
    }

    our sub parse_subname($target, $pos is copy) {
        my $targetlen = $target.chars;
        my $startpos = $pos;
        while $pos < $targetlen && $target.substr($pos, 1) ~~ /\w/ {
            ++$pos;
        }
        my $subname = $target.substr($startpos, $pos - $startpos);
        return $subname, $pos;
    }

    our sub parse_subrule($mob) {
        my $m = GGE::Exp::Subrule.new($mob);
        my $target = $mob.target;
        my $key = $mob<KEY>;
        if $key eq '<!' {
            $m<isnegated> = True;
        }
        if $key eq '<?' | '<!' {
            $m<iszerowidth> = True;
        }
        my ($subname, $pos) = parse_subname($target, $mob.to);
        my $cname = $subname;
        if $target.substr($pos, 1) eq ' ' {
            $m.to = ++$pos;
            # RAKUDO: Cannot call a sub named 'regex'
            #         without the '&' [perl #72438]
            my $arg = &regex($m, :stop('>'));
            return $m unless $arg;
            $m<arg> = ~$arg;
            $pos = $arg.to;
            $m.to = -1;
        }
        elsif $target.substr($pos, 1) eq '=' {
            ++$pos;
            ($subname, $pos) = parse_subname($target, $pos);
        }
        if $target.substr($pos, 1) eq '>' {
            ++$pos;
            $m.to = $pos;
            $m<iscapture> = True;
        }
        $m<subname> = $subname;
        $m<cname> = q['] ~ $cname ~ q['];
        return $m;
    }

    our sub parse_enumcharclass($mob) {
        my $m;
        my $target = ~$mob.target;
        my $pos = $mob.to;
        my $op = $mob<KEY>;
        if $op.substr(-1) eq '[' {
            $op .= chop;
        }
        loop {
            my $term;
            ++$pos while $target.substr($pos, 1) ~~ /\s/;
            if $op eq '<'
               || $target.substr($pos, 1) eq '[' { # enumerated character class
                ++$pos unless $op eq '<';
                my Str $charlist = '';
                my Bool $isrange = False;
                loop {
                    die "perl6regex parse error: Missing close '>' or ']>' ",
                        "in enumerated character class"
                        if $pos >= $target.chars;
                    given my $char = $target.substr($pos, 1) {
                        when ']' {
                            last;
                        }
                        when '.' {
                            proceed if $target.substr($pos, 2) ne '..';
                            $pos += 2;
                            ++$pos while $target.substr($pos, 1) ~~ /\s/;
                            $isrange = True;
                            next;
                        }
                        when '-' {
                            die "perl6regex parse error: Unescaped '-' in ",
                                "charlist (use '..' or '\\-')";
                        }
                        when '\\' {
                            ++$pos;
                            $char = $target.substr($pos, 1);
                            proceed;
                        }
                        when /\s/ {
                            ++$pos;
                            next;
                        }
                        if $isrange {
                            $isrange = False;
                            my $fromchar = $charlist.substr(-1, 1);
                            die 'perl6regex parse error: backwards range ',
                                "$fromchar..$char not allowed"
                                if $fromchar gt $char;
                            $charlist ~= $_ for $fromchar ^.. $char;
                        }
                        else {
                            $charlist ~= $char;
                        }
                    }
                    ++$pos;
                }
                ++$pos;
                $term = GGE::Exp::EnumCharList.new($mob);
                $term.to = $pos;
                $term.make($charlist);
            }
            else { # subrule
                my ($subname, $newpos) = parse_subname($target, $pos);
                die 'perl6regex parse error: Error parsing ',
                    'enumerated character class'
                    if $newpos == $pos;
                $term = GGE::Exp::Subrule.new($mob);
                $term.from = $pos;
                $term.to = $newpos;
                $term<subname> = $subname;
                $term<iscapture> = False;
                $pos = $newpos;
            }
            if $op eq '+' {
                my $alt = GGE::Exp::Alt.new($mob);
                $alt.to = $pos;
                $alt[0] = $m;
                $alt[1] = $term;
                $m = $alt;
            }
            elsif $op eq '-' {
                $term<isnegated> = True;
                $term<iszerowidth> = True;
                my $concat = GGE::Exp::Concat.new($mob);
                $concat.to = $pos;
                $concat[0] = $term;
                $concat[1] = $m;
                $m = $concat;
            }
            elsif $op eq '<' | '<+' {
                $m = $term;
            }
            else { # '<-' | '<!'
                $term<isnegated> = True;
                $term<iszerowidth> = True;
                if $op eq '<!' {
                    $m = $term;
                }
                else {
                    $m = GGE::Exp::Concat.new($mob);
                    my $dot = GGE::Exp::CCShortcut.new($mob);
                    $dot.make('.');
                    $m.to = $pos;
                    $m[0] = $term;
                    $m[1] = $dot;
                }
            }
            ++$pos while $target.substr($pos, 1) ~~ /\s/;
            $op = $target.substr($pos, 1);
            ++$pos;
            next if $op eq '+' | '-';
            last if $op eq '>';
            die 'perl6regex parse error: Error parsing ',
                'enumerated character class';
        }
        $m.to = $pos;
        return $m;
    }

    our sub parse_quoted_literal($mob) {
        my $m = GGE::Exp::Literal.new($mob);

        my $target = ~$m.target;
        my $lit = '';
        my $pos = $mob.to;
        until (my $char = $target.substr($pos, 1)) eq q['] {
            if $char eq '\\' {
                ++$pos;
                $char = $target.substr($pos, 1);
            }
            $lit ~= $char;
            ++$pos;
            die "perl6regex parse error: No closing ' in quoted literal"
                if $pos >= $target.chars;
        }
        $m.make($lit);
        $m.to = $pos + 1;
        $m;
    }

    our sub parse_quant($mob) {
        my $m = GGE::Exp::Quant.new($mob);

        my $key = $mob<KEY>;
        my ($mod2, $mod1);
        given $m.target {
            $mod2 = .substr($mob.to, 2);
            $mod1 = .substr($mob.to, 1);
        }

        $m<min> = 1;
        if $key eq '*' | '?' {
            $m<min> = 0;
        }

        $m<max> = 1;
        if $key eq '*' | '+' | '**' {
            $m<max> = Inf;
        }

        #   The postfix:<:> operator may bring us here when it's really a
        #   term:<::> term.  So, we check for that here and fail this match
        #   if we really have a cut term.
        if $key eq ':' && $mod1 eq ':' {
            return $m;
        }

        $m.to = $mob.to;
        if $mod2 eq ':?' {
            $m<backtrack> = GGE::Exp::Backtracking::EAGER;
            $m.to += 2;
        }
        elsif $mod2 eq ':!' {
            $m<backtrack> = GGE::Exp::Backtracking::GREEDY;
            $m.to += 2;
        }
        elsif $mod1 eq '?' {
            $m<backtrack> = GGE::Exp::Backtracking::EAGER;
            ++$m.to;
        }
        elsif $mod1 eq '!' {
            $m<backtrack> = GGE::Exp::Backtracking::GREEDY;
            ++$m.to;
        }
        elsif $mod1 eq ':' || $key eq ':' {
            $m<backtrack> = GGE::Exp::Backtracking::NONE;
            ++$m.to;
        }

        if $key eq '**' {
            # XXX: Should also count ws before quant modifiers -- with tests
            my $sepws = ?($m.target.substr($m.to, 1) ~~ /\s/);
            ++$m.to while $m.target.substr($m.to, 1) ~~ /\s/;
            my $isconst = $m.target.substr($m.to, 1) ~~ /\d/;
            my $sep = !$isconst;
            if (~$m.target).substr($m.to, 1) eq '{' {
                $sep = False;
                ++$m.to;
            }
            if $sep {
                # RAKUDO: Cannot call a sub named 'regex'
                #         without the '&' [perl #72438]
                my $repetition_controller = &regex($m, :tighter<infix:>);
                die 'perl6regex parse error: Error in repetition controller'
                    unless $repetition_controller;
                my $pos = $repetition_controller.to;
                $repetition_controller = $repetition_controller<expr>;
                if $sepws {
                    my $concat = GGE::Exp::Concat.new($m);
                    $concat.to = $pos;
                    my $ws1 = GGE::Exp::WS.new($m);
                    $ws1.to = $pos;
                    $concat.push($ws1);
                    $concat.push($repetition_controller);
                    my $ws2 = GGE::Exp::WS.new($m);
                    $ws2.to = $pos;
                    $concat.push($ws2);
                    $repetition_controller = $concat;
                }
                $m<sep> = $repetition_controller;
                $m<min> = 1;
                $m<max> = Inf;
                $m.to = $pos;
            }
            else {
                # XXX: Add test against non-digits inside braces .**{x..z}
                # XXX: Need to generalize this into parsing several digits
                $m<min> = $m<max> = $m.target.substr($m.to, 1);
                ++$m.to;
                if (~$m.target).substr($m.to, 2) eq '..' {
                    $m.to += 2;
                    $m<max> = (~$m.target).substr($m.to, 1);
                    if $m<max> eq '*' {
                        $m<max> = 'Inf';
                    }
                    ++$m.to;
                }
                if !$isconst {
                    die 'No "}" found'
                        unless (~$m.target).substr($m.to, 1) eq '}';
                    ++$m.to
                }
            }
        }

        $m;
    }

    our sub parse_dollar($mob) {
        my $pos = $mob.to;
        my $target = ~$mob.target;
        if $target.substr($pos, 1) eq '<' {
            my $closing-pos = $target.index('>', $pos);
            die "perl6regex parse error: Missing close '>' in scalar"
                unless defined $closing-pos;
            my $m = GGE::Exp::Scalar.new($mob);
            # XXX: PGE escapes the thing here. Not sure about exactly how.
            $m<cname>
                = sprintf "'%s'",
                          $target.substr($pos + 1, $closing-pos - $pos - 1);
            $m.to = $closing-pos + 1;
            return $m;
        }
        ++$pos while $target.substr($pos, 1) ~~ /\d/;
        if $pos > $mob.to {
            my $m = GGE::Exp::Scalar.new($mob);
            $m<cname> = $target.substr($mob.to, $pos - $mob.to);
            $m.to = $pos;
            return $m;
        }
        my $m = GGE::Exp::Anchor.new($mob);
        $m.to = $pos;
        return $m;
    }

    our sub parse_modifier($mob) {
        my $m = GGE::Exp::Modifier.new($mob);
        my $target = ~$m.target;
        my $pos = $mob.to;
        my $value = 1;
        my $end-of-num-pos = $pos;
        while $target.substr($end-of-num-pos, 1) ~~ /\d/ {
            ++$end-of-num-pos;
        }
        if $end-of-num-pos > $pos {
            $value = $target.substr($pos, $end-of-num-pos - $pos);
            $pos = $end-of-num-pos;
        }
        my $word = ($target.substr($pos) ~~ /^\w+/).Str;
        my $wordchars = $word.chars;
        return $m   # i.e. fail
            unless $wordchars;
        $pos += $wordchars;
        $m.make($value);
        if $target.substr($pos, 1) eq '(' {
            ++$pos;
            my $closing-paren-pos = $target.index(')', $pos);
            $m.make($target.substr($pos, $closing-paren-pos - $pos));
            $pos = $closing-paren-pos + 1;
        }
        $m<key> = $word;
        $m.to = $pos;
        $m;
    }

    multi sub perl6exp(GGE::Exp $exp is rw, %pad) {
        return $exp;
    }

    multi sub perl6exp(GGE::Exp::Modifier $exp is rw, %pad) {
        my $key = $exp<key>;
        if $key eq 'i' {
            $key = 'ignorecase';
        }
        if $key eq 's' {
            $key = 'sigspace';
        }
        my $temp = %pad{$key};
        %pad{$key} = $exp.ast;
        $exp[0] = perl6exp($exp[0], %pad);
        %pad{$key} = $temp;
        return $exp[0];
    }

    multi sub perl6exp(GGE::Exp::Concat $exp is rw, %pad) {
        my $n = $exp.elems;
        my @old-children = $exp.list;
        $exp.clear;
        for @old-children -> $old-child {
            my $new-child = perl6exp($old-child, %pad);
            if defined $new-child {
                $exp.push($new-child);
            }
        }
        # XXX: One difference against PGE here:
        #      no subsequent simplification in the case of only 1
        #      remaining element.
        return $exp;
    }

    multi sub perl6exp(GGE::Exp::Quant $exp is rw, %pad) {
        my $isarray = %pad<isarray>;
        %pad<isarray> = True;
        $exp[0] = perl6exp($exp[0], %pad);
        if $exp<sep> -> $sep {
            $exp<sep> = perl6exp($sep, %pad);
        }
        %pad<isarray> = $isarray;
        $exp<backtrack> //= %pad<ratchet>
            ?? GGE::Exp::Backtracking::NONE()
            !! GGE::Exp::Backtracking::GREEDY;
        return $exp;
    }

    multi sub perl6exp(GGE::Exp::Alt $exp is rw, %pad) {
        if !defined $exp[1] {
            return perl6exp($exp[0], %pad);
        }
        if $exp[0] ~~ GGE::Exp::WS {
            return perl6exp($exp[1], %pad);
        }
        if $exp[1] ~~ GGE::Exp::WS {
            die 'Perl6Regex rule error: nothing not allowed in alternations';
        }
        my $subpats-before = %pad<subpats> // 0;
        $exp[0] = perl6exp($exp[0], %pad);
        my $subpats-after0 = %pad<subpats> // 0;
        %pad<subpats> = $subpats-before;
        $exp[1] = perl6exp($exp[1], %pad);
        my $subpats-after1 = %pad<subpats> // 0;
        %pad<subpats> = [max] $subpats-after0, $subpats-after1;
        return $exp;
    }

    multi sub perl6exp(GGE::Exp::Conj $exp is rw, %pad) {
        if $exp[1] ~~ GGE::Exp::Alt && !defined $exp[1][1] {
            die 'Perl6Regex rule error: "&|" not allowed';
        }
        $exp[0] = perl6exp($exp[0], %pad);
        $exp[1] = perl6exp($exp[1], %pad);
        return $exp;
    }

    multi sub perl6exp(GGE::Exp::Group $exp is rw, %pad) {
        $exp[0] = perl6exp($exp[0], %pad);
        return $exp;
    }

    multi sub perl6exp(GGE::Exp::CGroup $exp is rw, %pad) {
        $exp<iscapture> = True;
        unless $exp.exists('isscope') {
            $exp<isscope> = True;
        }
        unless $exp.exists('cname') {
            my $subpats = %pad<subpats> // 0;
            $exp<cname> = $subpats;
        }
        %pad<subpats> = $exp<cname> + 1;
        my $isarray = %pad<isarray> // False;
        if $exp<isscope> {
            $exp<isarray> = $isarray;
            %pad<isarray> = False;
            my $subpats = %pad<subpats>;
            %pad<subpats> = 0;
            $exp[0] = perl6exp($exp[0], %pad);
            %pad<subpats> = $subpats;
            %pad<isarray> = $isarray;
        }
        else {
            $exp[0] = perl6exp($exp[0], %pad);
        }
        return $exp;
    }

    multi sub perl6exp(GGE::Exp::Subrule $exp is rw, %pad) {
        my $cname = $exp<cname>;
        my $isarray = %pad<isarray>;
        if %pad<lexscope>.exists($cname) {
            %pad<lexscope>{$cname}<isarray> = True;
            $isarray = True;
        }
        %pad<lexscope>{$cname} = $exp;
        $exp<isarray> = $isarray;
        return $exp;
    }

    multi sub perl6exp(GGE::Exp::Cut $exp is rw, %pad) {
        $exp<cutmark> =
               $exp.ast eq '::'  ?? GGE::Exp::CutType::CUT_GROUP()
            !! $exp.ast eq ':::' ?? GGE::Exp::CutType::CUT_RULE()
            !!                      GGE::Exp::CutType::CUT_MATCH;
        return $exp;
    }

    multi sub perl6exp(GGE::Exp::Literal $exp is rw, %pad) {
        $exp<ignorecase> = %pad<ignorecase>;
        return $exp;
    }

    multi sub perl6exp(GGE::Exp::WS $exp is rw, %pad) {
        if %pad<sigspace> {
            $exp<subname> = 'ws';
            $exp<iscapture> = False;
            return $exp;
        }
        else {
            return Mu; # should be Nil, but we need to store the result
                       # from this call in a variable, and currently
                       # Rakudo promotes a Nil to something defined when
                       # it's stored into a variable, making the subsequent
                       # undefinedness test fail
        }
    }

    multi sub perl6exp(GGE::Exp::Alias $exp is rw, %pad) {
        unless $exp[0] ~~ GGE::Exp::Scalar {
            die 'perl6regex parse error: LHS of alias must be lvalue';
        }
        my $cname = $exp[0]<cname>;
        my $exp1 = $exp[1];
        if $exp1 ~~ GGE::Exp::CGroup {
            $exp1<cname> = $cname;
            $exp1 = perl6exp($exp1, %pad);
            return $exp1;
        }
        if $exp1 ~~ GGE::Exp::Quant {
            die "We don't handle that case yet";
        }
        my $cexp = GGE::Exp::CGroup.new($exp);
        $cexp.from = $exp.from;
        $cexp.to   = $exp.to;
        $cexp[0]   = $exp1;
        $cexp<isscope> = False;
        $cexp<cname> = $cname;
        $cexp = perl6exp($cexp, %pad);
        return $cexp;
    }
}

augment class GGE::Match {
    multi method before() {
        return GGE::Match.new(self); # a failure
    }

    multi method before($pattern) {
        my $rule = GGE::Perl6Regex.new($pattern);
        my $mob = $rule(self);
        if $mob { # 'before' matches are always zero-width
            $mob.to = $mob.from;
        }
        return $mob;
    }

    method after($pattern) {
        my $rule = GGE::Perl6Regex.new('[' ~ $pattern ~ ']$');
        my $mob = $rule(self.target.substr(0, self.to));
        if $mob { # 'after' matches are always zero-width
            $mob.from = $mob.to = self.to;
        }
        return $mob;
    }
}
