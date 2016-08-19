#!/usr/bin/perl
use SarcasmAnalysis::Tweet;
use SarcasmAnalysis::Attributes;
use Getopt::Long;
use Text::Aspell;

eval(GetOptions("unigrams", "bigrams", "hashtags", "spellcheck", "lc", "stop=s", "skewed", "non_skewed", "SMO", "help")) or die ("Please check the above mentioned option(s).\n");

#cannot have both skewed and non_skewed
if(defined $opt_skewed && defined $opt_non_skewed){
    die "Cannot analyze both skewed and non-skewed data sets...";
}#end if

#if help is defined, print out help
if(defined $opt_help){
    $opt_help = 1;
    &showHelp;
    exit;
}#end if

#if stop is defined, it will take out stopwords from a list
my $regex = "";
if(defined $opt_stop){
    $regex = stop();
}#end if

#sets the file
my $file = "";
if(defined $opt_skewed){
    $file = "twitter-sarcasm-skewed.tweets.txt";
}#end if
if(defined $opt_non_skewed){
    $file = "twitter-sarcasm-#-download.sarcasm.tweets.txt";
}#end if

#these are to calculate the average number of tweets per bucket correct/incorrect
my $avgCorrect = 0;
my $avgIncorrect = 0;
#these are to calculate the average percentage of tweets per bucket correct/incorrect
my $avgPerCorrect = 0;
my $avgPerIncorrect = 0;

#goes through all the tweets, breaks them down into attributes, formats them, sends them to Weka
for (my $testBucket = 1; $testBucket < 11; $testBucket++){

    print "bucket -- $testBucket\n";
    open(FILE, $file) || die "Could not open FILE...\n"; 
    my %docAtts = (); #stores how many times an attribute is said in all of the training tweets
    my %tweets = (); #stores objects that contain %tweetWords, $tweetHTs, and $bucket
    my %indeces = ();#stores the index number so I can call what I need outside the first while loop
    my %tweetRating = ();#stores the rating of all the tweets
    my %tweetSentiment = (); #stores the sentiment of all the tweets (positive, negative, neutral)
    my $i = 0;
    my $k = 0;
    my $bucket = 1; #the bucket we are on. Program goes through the entire process ten times, with a different test bucket each time. If this bucket number equals the test bucket number, those tweets will get tested on. Otherwise, they are trained on
        
    #getting all the tweets and attributes filed into hash tables properly
    while(<FILE>){
	if($bucket == 11){
	    $bucket = 1;
	}#end if

	#getting rid of white space
	chomp; 
	$_=~s/\s+/ /g; 
	$_=~s/^\s*//g; 
	$_=~s/\s*$//g; 

	my $line = $_;
	chomp $line;
	my @parts = split /\s+/, $line;

	#getting rid of not available tweets
	if ($parts[4] eq "Not" && $parts[5] eq "Available"){
	    next;
	}#end if

	my %tweetAtts = (); #stores how many times an attribute is said in a tweet
	$i = 0;
	my $l = 0;
	my $index = shift @parts;
	my $rating = shift @parts;
	
	#making sure the right formatting leads to the right output
	if(defined $opt_non_skewed){
	    if($rating=~/TN/g){
		$rating = "not_sarcastic";
	    }#end if
	    else{
		$rating = "sarcastic";
	    }#end else
	}#end if

	#grabbing the sentiment as an attribute
	my $sentiment = shift @parts;
	if($sentiment=~/positive/){
	    $sentiment = "pos";
	}#end if
	elsif($sentiment=~/negative/){
	    $sentiment = "neg";
	}#end elsif
	else{
	    $sentiment = "neut";
	}#end else

	my $rate = shift @parts;

	#making sure the right formatting leads to the right output
	if(defined $opt_skewed){
	$rating = "null";
	    if($rate == 1.0){
		$rating = "sarcastic";
	    }#end if
	    else{
		$rating = "not_sarcastic";
	    }#end else
	}#end if

	#cleaning stuff up - getting rid of some emojis, ellipses, and spellchecking. Also getting rid of all punctuation (except @ and #) because Weka doesn't like most punctuation
	foreach my $part (@parts){
	    if($part=~/^[:].*[)]$/gm){
		$part = "happy";
	    }#end elsif
	    elsif($part=~/^[:].*[D]/gm){
		$part = "laughing";
	    }#end elsif
	    elsif($part=~/\.{3,}?/g){
		push @parts, "dots";
	    }#end elsif
	    
	    if(defined $opt_lc){
		$part = lc($part);
	    }#end if

	    if(defined $opt_spellcheck){
		my @suggestions = ();
		my $speller = Text::Aspell->new;
		if($speller->check($part)){
		    #do nothing
		}#end if
		else{
		    @suggestions = $speller->suggest($part); #getting any suggestions for the misspelled word
		    if(exists $suggestions[0]){ #if there are suggestions
			$part = $suggestions[0]; #take the first one
		    }#end if
		}#end else
	    }#end if

	    $part=~s/[^@#\w]//g; #get rid of anything but @, #, _, digits, and letters

	}#end foreach

	#places all the words correctly
	while (@parts + 0 > 0){ #while there are still things in the array
	    my $word = shift @parts;

	    if($word=~/sarcas/ || $word=~/^\s*$/ || (defined $opt_stop && $word=~/$regex/i)){ #if the word contains sarcas (for sarcasm/sarcastic) or is a space or is a stopword move on
		next;
	    }#end if

	    my $hashtag = substr($word, 0, 1); #takes the first character
	    if($hashtag eq "#"){
		if(defined $opt_hashtags){
		    $tweetAtts{$word} = 1; #put it in the tweet attributes hash table
		}#end if
		else{
		    next; #otherwise move on to the next word
		}#end else
	    }#end if

	    #vowels to consonants ratio - shortens words with excessive amounts of letters in a row
	    my @wordArr = split "", $word;
	    for(my $i = 0; $i < @wordArr+0; $i++){
		my $letter = $wordArr[$i];
		if ($i + 3 < @wordArr+0){
		    if ($letter=~m/[\D]/ && $letter eq $wordArr[$i+1] && $letter eq $wordArr[$i+2] && $letter eq $wordArr[$i+3]){ #makes sure the character isn't a digit then makes sure there are 4 in a row
			while($i + 3 < @wordArr+0 && $letter eq $wordArr[$i+3]){
			    splice @wordArr, $i+3, 1;
			}#end while
		    }#end if
		}#end if
	    }#end for
	    $word = join "", @wordArr;
	    
	    $i = 0;

	    #collects the bigrams
	    my $bigram = "";
	    my $bigramCount = 1;
	    if(defined $opt_bigrams){
		my $int = 0;
		my $word2 = "";
		#makes sure there are two words left in the tweet to make a bigram, and that they aren't in the stopwords list
		while(@parts + 0 > $int){ #while there are still words left in the array
		    $word2 = $parts[$int];
		    if(defined $word2){
			chomp $word2;
			my $tag = substr($word2, 0, 1);
			if(($tag eq "#") || ($opt_stop && $word2=~/$regex/i) || $word2=~/sarcas/){ #if the second word is a hashtag or stopword or contains sarcas (for sarcasm/sarcastic) move on
			    $int++;
			}#end if
			else{
			    $bigram = "$word $word2"; #otherwise make the bigram and quit out
			    $bigram = lc($bigram);
			    last;
			}#end else
		    }#end if
		}#end while
		if($bigram=~/.+ .+/){ #makes sure it is two words
		    $tweetAtts{$bigram} = 1; #put it in the tweet attributes hash table
		}#end if
	    }#end if

	    #collects the unigrams
	    if(defined $opt_unigrams){
		$tweetAtts{$word} = 1; #put it in the tweet attributes hash table
	    }#end if

	    #getting a hashtable of all the words in the document
	    if($testBucket != $bucket){
		my $docCount = 1; #the number of times the attribute is used in the document

		if(defined $opt_unigrams){
		    if(exists $docAtts{$word}){
			$docCount = $docAtts{$word};
			$docAtts{$word} = $docCount+1;
		    }#end if
		    else{
			$docAtts{$word} = 1;
		    }#end else
		}#end if		    

		if(defined $opt_hashtags){
                    #checks to see if the word is a hashtag
		    if ($hashtag eq "#"){ #if the word is a hashtag
			if(exists $docAtts{$word}){
			    $docCount = $docAtts{$word};
			    $docAtts{$word} = $docCount+1;
			}#end if
			else{
			    $docAtts{$word} = 1;
			}#end else
			$tweetAtts{$word} = 1;
		    }#end if
		}#end if

		if(defined $opt_bigrams){
		    if(exists $docAtts{$bigram}){
			$docCount = $docAtts{$bigram};			
			$docAtts{$bigram} = $docCount+1;
		    }#end if
		    else{
			if($bigram=~/.+ .+/){
			    $docAtts{$bigram} = 1;#set it equal to whatever the bigram count is
			}#end if
		    }#end else
		}#end if
	    }#end if
	}#end while

	$tweetSentiment{$index} = $sentiment; #collects the sentiment for each tweet
	$tweetRating{$index} = $rating; #collects the rating for each tweet
	$indeces{$k} = $index; #stores each tweet's index so we can access the other hash tables later
	$tweets{$index}	= new SarcasmAnalysis::Tweet(\%tweetAtts, $bucket); #a hashtable of Tweet objects
	$k++;
	$bucket++;

    }#end while

    #determining if the tweet contains an attribute or not - goes through the attributes and marks if the tweet has it or not
    my %tweetsAttributes = (); #stores a hashtable of attributes to be accessed later
    foreach my $index_btm (sort keys %indeces){
	my $index = $indeces{$index_btm}; 
	my $contains = 0; #will say if the tweet contains a certain attribute
	my %attributes = ();

	my $attss = $tweets{$index}->getAttributes();
	my $sentiment = $tweetSentiment{$index};

	#getting the @ATTRIBUTEs ready
	foreach my $key (sort keys %docAtts){
	    if(exists ${$attss}{$key}) { 
		$attributes{$key} = 1; #log(476/($docAtts{$key}));
	    }#end if
	    else{
		$attributes{$key} = 0;
	    }#end else
	}#end foreach

	if($sentiment=~/pos/i){
	    $attributes{"~~~sentiment"} = 1;
	}#end if
	elsif($sentiment=~/neut/i){
	    $attributes{"~~~sentiment"} = 0;
	}#end elsif
	else{
	    $attributes{"~~~sentiment"} = -1;
	}#end elsif

	$tweetsAttributes{$index} = new SarcasmAnalysis::Attributes(\%attributes);#a hashtable of Attribute objects

    }#end foreach

    #making the ARFF files -- making two bc we need a test and a train one
    open(ARFF, '>', "tweetsTrainBucket$testBucket.arff") || die "Could not open ARFF...";
    print ARFF "@"."RELATION tweet_sentiment_train_bucket_$testBucket\n\n";
    open(ARFFtest, '>', "tweetsTestBucket$testBucket.arff") || die "Could not open ARFFtest...";
    print ARFFtest "@"."RELATION tweet_sentiment_test_bucket_$testBucket\n\n";
 
    foreach my $key (sort keys %docAtts){
	$key = "'$key'";
    	print ARFF "@"."ATTRIBUTE $key NUMERIC\n";
    	print ARFFtest "@"."ATTRIBUTE $key NUMERIC\n";
    }#end foreach
    print ARFF "@"."ATTRIBUTE sentiment NUMERIC\n";
    print ARFFtest "@"."ATTRIBUTE sentiment NUMERIC\n";

    print ARFF "@"."ATTRIBUTE label {sarcastic, not_sarcastic}\n";
    print ARFFtest "@"."ATTRIBUTE label {sarcastic, not_sarcastic}\n";
    print ARFF "\n@"."DATA\n";
    print ARFFtest "\n@"."DATA\n";

    #prints the tweet vector - whether a word is contained or not for every word, and the sentiment and sarcastic ratings
    foreach my $k (sort keys %indeces){ 
	my $index = $indeces{$k};
	my $attributes = $tweetsAttributes{$index}->getAttributes();
	$bucket = $tweets{$index}->getBucket();
	if ($testBucket == $bucket){
	    foreach my $key (sort keys %{$attributes}){
		print ARFFtest "${$attributes}{$key},";
	    }#end foreach

	    print ARFFtest "$tweetRating{$index}\n";
	}#end if
	else{
	    foreach my $key (sort keys %{$attributes}){
		print ARFF "${$attributes}{$key},";
	    }#end foreach

	    print ARFF "$tweetRating{$index}\n";
	}#end else
    }#end foreach

    weka("tweetsTrainBucket$testBucket.arff", "tweetsTestBucket$testBucket.arff", $testBucket);

    #getting the average accuracy
    open(ACC, "accuracyForBucket$testBucket.txt") or die "Could not open ACC...";
    my $correctInstances = "";
    my $incorrectInstances = "";
    while(<ACC>){
	my $line = $_;
	if ($line=~/^=== Error on test data ===/){
	    <ACC>;
	    $correctInstances = <ACC>; #grabs the row with data of how many tweets were labeled correctly
	    $incorrectInstances = <ACC>; #grabs the row with data of how many tweets were labeled incorrectly
	    last;
	}#end if
    }#end while
    
    #adds up all the correct values
    my @correct = split /\s+/, $correctInstances;
    my $numCorrect = $correct[3];
    my $perCorrect = $correct[4];
    $avgCorrect = $avgCorrect + $numCorrect;
    $avgPerCorrect = $avgPerCorrect + $perCorrect;

    #adds up all the incorrect values
    my @incorrect = split /\s+/, $incorrectInstances;
    my $numIncorrect = $incorrect[3];
    my $perIncorrect = $incorrect[4];
    $avgIncorrect = $avgIncorrect + $numIncorrect;
    $avgPerIncorrect = $avgPerIncorrect + $perIncorrect;

    print "Test Bucket $testBucket Percent Correct -- $perCorrect  Percent Incorrect -- $perIncorrect\n";
}#end for

#averages the correct and incorrect values from all the buckets
$avgCorrect = $avgCorrect/10;
$avgIncorrect = $avgIncorrect/10;
$avgPerCorrect = sprintf("%.2f", $avgPerCorrect/10);
$avgPerIncorrect = sprintf("%.2f", $avgPerIncorrect/10);
print "\n\nAverage Amount Correct -- $avgCorrect | Average Amount Incorrect -- $avgIncorrect\n";
print "Average Percent Correct -- $avgPerCorrect | Average Percent Incorrect -- $avgPerIncorrect\n";

#calls Weka
sub weka{
    my $docs = scalar(@_);
    my $train = $_[0];
    my $test = $_[1];
    my $tb = $_[2];
    if(defined $opt_SMO){
	my $accuracy = system("java weka.classifiers.functions.SMO -t $train -T $test > accuracyForBucket$tb.txt");
    }#end if
    else{
	my $accuracy = system("java weka.classifiers.bayes.NaiveBayes -t $train -T $test > accuracyForBucket$tb.txt");
    }#end else
}#end sub

#the help option
sub showHelp() {

    print "\nThis is a utility that provides an example of how to set\n";
    print "and use the GetOptions module for the programs written in\n"; 
    print "our lab -- this includes the help and showVersion information\n\n";

    print "Usage: GetOptionsExample.pl [OPTIONS] \n\n";
    print "OPTIONS:\n\n";
    print "--unigrams               Runs the program evaulating using unigrams\n\n";
    print "--bigrams                Runs the program evalutating using bigrams\n\n";
    print "--hashtags               Runs the program evaluating using hashtags\n\n";
    print "--spellcheck             Checks the spelling of each word and will supply a new word if the original is spelled wrong\n\n";
    print "--lc                     Runs the program with each word in all lowercase, as opposed to some words and letters being capitalized\n\n";
    print "--stop STOPFILE          Takes the stop file STOPFILE and will not analyze any words in this file\n\n";
    print "--skewed                 Runs the program on the skewed data set\n\n";
    print "--non_skewed             Runs the program on the non-skewed data set\n\n";
    print "--SMO                    Runs Weka with SMO classifier - program default is Naive Bayes classifier\n\n";
    print "--help                   Prints this help message.\n\n";
}#end sub

#the stopwords option
sub stop { 
    
    my $stop_regex = "";
    my $stop_mode = "AND";

    open ( STP, $opt_stop ) ||
        die ("Couldn't open the stoplist file $opt_stop\n");
    
    while ( <STP> ) {
	chomp; 
	
	if(/\@stop.mode\s*=\s*(\w+)\s*$/) {
	    $stop_mode=$1;
	    if(!($stop_mode=~/^(AND|and|OR|or)$/)) {
		print STDERR "Requested Stop Mode $1 is not supported.\n";
		exit;
	    }
	    next;
	} 
	
	# accepting Perl Regexs from Stopfile
	s/^\s+//;
	s/\s+$//;
	
	#handling a blank lines
	if(/^\s*$/) { next; }
	
	#check if a valid Perl Regex
        if(!(/^\//)) {
	    print STDERR "Stop token regular expression <$_> should start with '/'\n";
	    exit;
        }
        if(!(/\/$/)) {
	    print STDERR "Stop token regular expression <$_> should end with '/'\n";
	    exit;
        }

        #remove the / s from beginning and end
        s/^\///;
        s/\/$//;
        
	#form a single big regex
        $stop_regex.="(".$_.")|";
    }

    if(length($stop_regex)<=0) {
	print STDERR "No valid Perl Regular Experssion found in Stop file $opt_stop";
	exit;
    }
    
    chop $stop_regex;
    
    # making AND a default stop mode
    if(!defined $stop_mode) {
	$stop_mode="AND";
    }
    
    close STP;
    
    return $stop_regex; 
}

