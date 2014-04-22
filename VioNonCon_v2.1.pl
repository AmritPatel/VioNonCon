#!/usr/bin/perl

use CAM::PDF;
use CAM::PDF::PageText;
use Roman;

####################################################################
#                                                                  #
# Strips out Part 21 violations and App B nonconformances when fed # 
# an ASCII formatted inspection report via command-line argument.  #
#                                                                  #
# Created on 8/19/2011 by Amrit D. Patel                           #
#                                                                  #
# Revised on 8/23/2011 by Amrit D. Patel                           #
#                                                                  #
# Revised on 8/26/2011 by Amrit D. Patel                           #
#                                                                  #
# -Added ability to process PDF files directly. User no longer     #
#  needs to convert to ascii text .                                #
#                                                                  #
# -Improved filter performance; false positives were reduced as    #
#  well as misses.                                                 #
#                                                                  #
####################################################################

##################   MAIN   ########################################

# Check to see if output files exist. 

if (-e "out.dat" or -e "matrix.out") {
 print "\nOutput files exist. Overwrite? [y/n] ";
 chomp($in=<STDIN>);
}

# Exits if user doesn't want to proceed, otherwise program continues.

if ($in =~ /n/i) {
 die "\nGoodbye!\n";
}

else {
 # do nothing
}; 

# Old files are deleted.

unlink "matrix.out";
unlink "out.dat";

# $n keeps track of how many input files are processed.

$n=0;

# This is a glob that sticks the name of each PDF file in the 
# working directory into an element of @array.

@array=<*.pdf>;

# This loop iterates over each filename stored in @array and dumps
# the corresponding contents of that file into the @temp array. In 
# this implementation, each entry of @temp corresponds to a line in
# the file that was dumped to it. 

foreach (@array) {
 
 # Iterate the file counter. 
  
 $n++;

 # Initialize (or clear) the @temp array.
 
 @temp=(); 
 
 # Dump the contents of the file that is the nth element of @array
 # to @temp.
 
 @temp = &pdf2txt("$_"); 
 
 # For code debugging
 # open (DBG, ">$n"); 
 # foreach (@temp) { 
 # print DBG "$_"; 
 # }
 # close (DBG);
 
 # Open a new file that will contain only a portion of the original
 # file since we want to limit the scope of the processing filter.

 open (SCR, ">scratch.dat");

 # Define a switch (initially off) that marks the beginning of the 
 # text to be transferred to the scratch file.

 $switch=0;
 
 # The $cnt variable is looking for the date that is printed at the 
 # beginning of the document, but not necessarily as the first line.
 # When it finds a date matching the regex that is shown in the 
 # proceeding IF statement, it stores the date in the @date array, 
 # which corresponds to the nth element of @array. Also, when this 
 # happens, $cnt iterates to 1, and the initial IF condition will 
 # not be met. This means that the program will stop looking for
 # the date as it continues to step through the file stored in 
 # @temp.

 $cnt=0; $vio=0; $noncon=0; $once=0;

 foreach (@temp) {
 
  # If the date hasn't been found yet (i.e. equals 0), continue the
  # search.
  
  if ($cnt == 0) {
   
   # If the pattern is matched (i.e. a date is found), put the 
   # contents of the line (excluding whitespace at the beginning of
   # the line) into the @date array and also remove the trailing
   # character.
   
   if (/\s*(\w+\s+\d\d?,\s+\d\d\d\d)/) {
    chomp($date[$n]=$1);

    # Iterate $cnt so it will stop searching for the date.

    $cnt++;
   }
   
   # If the date has not been found, keep searching.

   else {
    $cnt=0;
   }

  }

  # If below phrases are found, begin printing the contents to the 
  # scratch file.
  
  if ( (/DISTRIBUTION/ or /distribution:?\s*\n/i) and $once == 0 ) {  # was previously /NOTICE OF VIOLATION/ or /NOTICE OF NONCONFORMANCE/
   $switch=1;
   $once=1;
  }
  
  # Flags to indicate if a violation or a nonconformance section exists
  
  if ( $_ =~ /VIOLATION/ and $switch == 1 ) { $vio = 1 };
  if ( $_ =~ /NONCONFORMANCE/ and $switch == 1) { $noncon = 1 };

  # If below phrases are found, end printing of contents to the 
  # scratch file.

  if (/EXECUTIVE SUMMARY/ or /INSPECTION|AUDIT SUMMARY/) {
   $switch=0;
  }

  # Prints to the scratch file if in NOTICE sections.

  if ($switch == 1) {
   print SCR "$_";
  }

 }

 # After the end of @temp is reached corresponding to the nth
 # filename of @array, close the scratch file.
 
 close (SCR);

 # Re-open the scratch file as read-only for further processing.

 open (PRC, "scratch.dat");

 # Dump the contents of the scratch file to @dat after
 # initialization.

 @dat=();
 @dat=<PRC>;

 # Close the scratch file.

 close (PRC);

 # Delete the no longer needed scratch file.

 unlink "scratch.dat";

 # Open the output file which be augmented and will contain the
 # matched text.

 open (OUT, ">>out.dat");

 # Print the date corresponding to the nth entry of @array to the 
 # out.dat file.

 print OUT "\n$date[$n]\n\n";

 # Initialize a new 2D matrix that will contain the flagged App B 
 # criteria and Part 21 regulations for each entry in @array.
 # There are 18 criteria in App B which correspond to a dimension
 # of @mat. Part 21 violations are indicated in the 19th position 
 # of that dimension (i.e. element 18). @mat has the same number 
 # of rows as @array, which defines the other dimension with n 
 # positions.
 
 for (0..18) { $mat[$n][$_]=(); }
 
 # Loop over the scratch file contents in @dat looking for
 # keywords that are essentially common for all inspection reports.

 # $ent is needed in case violation section comes after
 # nonconformance section.
 
 $ent=0; 
 
 foreach (@dat) {

  # If the keywords are matched in the IF block below, then print
  # that line to "out.dat". This is looking for Part 21 violations.

  if (/^\s*[A-Z]?\.?\s*10 CFR Part 21/ or /Criterion/ or /Title 10/ or /10 CFR 21/ or /Part 21/) {

   print OUT;

   # Additionally, this line is further filtered, and if "21" is
   # matched anywhere in the line that was initially matched, it
   # will flag it as indicating a Part 21 violation and an "x" is
   # placed in the 19th element of @mat. This was designed to be
   # extra cautious by using $vio to ensure that a violatation was
   # actually flagged.

   if ($vio == 1 and $_ =~ /21/) {

    $mat[$n][18]=x;
	$ent=1;

   }

   # If the keywords are matched in the IF block below, then print
   # that line to out.dat. The keywords start with "Criterion" and 
   # are followed by a Roman numeral between 1 and 18. Note the \b
   # modifier being used. This is necessary to limit what is 
   # captured in the parentheses to all text up to only the 1st 
   # comma. The ternary operator is implemented to allow matching
   # of up to a 4 character Roman numeral. This filter is looking
   # for App B nonconformances.

   elsif (/\bCriterion ([A-Z][A-Z]?[A-Z]?[A-Z]?[A-Z]?),?\b/) {

    # This calls the arabic function as part of the module "Roman."
    # It converts the matched Roman numeral into an Arabic numeral.
    # That number is then mapped to the correct element of @mat to 
    # flag a particular nonconformance.

    # Gets rid of flagging App B criteria in the Part 21 section.
	# Also disallows Part 21 flagging in the "Notice of
	# Nonconformance" section unless the report is formatted as a
	# QA inspection report (which only has one section titled
	# "Notice of Violation"). In the latter case, there is a
	# chance of flagging a Part 21 violation even though only
	# App B citations exist. This is due to the fact that 
	# both Part 21 violations and App B violations exist 
	# in the same section for QA inspection reports.
	
	if ($ent == 0) {
	 # do nothing
	}
    elsif ($ent == 1) { 
	 $vio=0;
    }	 
	
	$arabic = arabic($1);
    $mat[$n][$arabic-1]=x;

   }

  }

 }

 # The "out.dat" file is closed. 

 close (OUT); 

} 

# Another file is created called "matrix.out". This file will contain
# the formatted output that will also be printed to the screen. The 
# data portion of the output file is formatted as comma separated
# values for easy input into MS Excel.

open (MATRIX, ">matrix.out");

# A title is printed.

print " \n                       Summary of Violations and Nonconformances\n";
print "                       -----------------------------------------\n";

print MATRIX "\n                       Summary of Violations and Nonconformances\n";
print MATRIX "                       -----------------------------------------\n";

# The labels are printed.

printf "\n%20s";
for (1..18) { printf "%3s", $_ };
print " 21";

printf MATRIX "\n%20s";
for (1..18) { printf MATRIX "%3s", $_ };
print MATRIX " 21";

# In descending order, the contents of @mat (i.e. the matched
# violations and nonconformances) are printed along with the
# date of the corresponding inspection report letter to the 
# vendor/applicant.

&HTML_gen($n);

for ($i=$n; $i>=1; $i--) {
 
 # The index $i is decremented and then placed into the variable
 # $case for readability. 

 $case=$i;

 # First the date is printed on a line.

 printf "\n%20s", $date[$case];
 printf MATRIX "\n%20s ", $date[$case]; 

 # Then all 19 entries of @mat (for the nth case) are printed on
 # the same line. 
  
 for (0..18) {

  # The entry is printed right-justified to the screen using
  # 3 characters. 

  printf "%3s", $mat[$case][$_];

  # If not at the last entry of the nth case of @mat, then print
  # the entry with a comma at the end to "matrix.out"...

  if ($_ != 18) {  
   printf MATRIX "%2s,", $mat[$case][$_];
  }

  # ...otherwise the last entry has been reached and no comma is 
  # printed to "matrix.out."

  else {
   printf MATRIX "%2s", $mat[$case][$_];
  }

 }

# The loop ends when all text files (i.e. files with .txt
# extensions) in the working directory have been processed.

}

# Print blank line for screen formatting.

print "\n";

# Print a message to the screen directing user to program exit.
  
print "\nPress ENTER to close ...\n";
$userin=<STDIN>;  

################## MAIN END ########################################


sub pdf2txt {

 my $filename = shift @_;
 
 open (OUT, ">scratch.dat");

 my $pdf = CAM::PDF->new($filename);
 my $pages = $pdf->numPages();

 for (1..$pages) {
 
  $pageone_tree = $pdf->getPageContentTree($_); 
  
   if ( defined($pageone_tree) ) {
    print OUT CAM::PDF::PageText->render($pageone_tree);
   }	
 
 } 

 close (OUT);
 
 open (SCR, "scratch.dat");
 
 @temp = <SCR>;
 
 close (SCR);
 
 unlink "scratch.dat";
 
 return @temp; 

}

sub HTML_gen {

 my $n = shift @_;
 my $i = ();
 my $roman = ();
 my $case = ();
 
 open (HTML, ">table.html");

 print HTML "\<table border=\"1\"\>\n";
 print HTML "\<tr\>\n";

 for (1..18) {

  $roman=Roman($_);
  print HTML "\<th\>$roman\</th\>\n";
  
 }
 
 print HTML "\<th\>Part 21\</th\>\n";
 print HTML "\</tr\>\n";
 
 for ($i=$n; $i>=1; $i--) {
 
  $case=$i;
  
  print HTML "\<tr\>\n";
  
  for (0..18) {
  
   print HTML "\<td\>$mat[$case][$_]\</td\>\n";
   
  }
  
  print HTML "\</tr\>\n";
  
 }

 print HTML "\</table\>\n";
 print HTML "\n\<p style=\"font-family:verdana,arial,sans-serif;font-size:12px;\"\>\<a href=\"http://www.nrc.gov/reactors/new-reactors/oversight/quality-assurance/vendor-insp/insp-reports.html\" target=\"_top\"\>Back\</a\>\</p\>\n";

}