package iOSSMSBackup;

use DBI;
use File::Copy;
use DateTime;
use Digest::SHA1  qw(sha1 sha1_hex sha1_base64);
use iOSMessages;
use iOSContacts;
use Data::Dumper;

my $export_d = "_export";

sub new
{
    my ($class, $params) = @_;
    my $self = {
        _backup_directory => $params->{backup_directory},
        _sms_db => undef
    };
    
    unless (-d $self->{_backup_directory}){
        die 'Directory does not exist';
    }
    
    bless $self, $class;
    return $self;
}


sub export_messages {
    my ($self) = @_;
  
    mkdir "_export" unless -d "_export";

    $self->_create_css_file();
   
    my $ios_messages = iOSMessages->new({backup_directory => $self->{_backup_directory}});
    my $messages = $ios_messages->get_messages;
    my $attachments = $ios_messages->get_attachments;
    my $contact_list = iOSContacts->new({backup_directory => $self->{_backup_directory}});
    my $contacts = $contact_list->get_contacts();
    foreach my $number (keys %$messages){
        #print "Exporting messages for $number\n";
	    
        mkdir "_export/$number" unless -d "$export_d/$number";

        foreach my $date (keys %{$messages->{$number}}){
            mkdir "_export/$number/$date" unless -d "_export/$number/$date";
            print "Contact is ";
            print Dumper$contacts->{$number};
            $self->create_html_file_for($number, $date, $messages->{$number}->{$date}, $contacts->{$number});
        }
    }
    return 1;
}

sub create_html_file_for{
    my ($self, $number, $date, $texts, $contact_info) = @_;
    open OUTFILE, ">_export/$number/$date/$date.html";
    print OUTFILE $self->html_header();
    
    my $title = qq|<div class="title_header">Texts with |;
    if ($contact_info && ($contact_info->{'first_name'} || $contact_info->{'last_name'})){
        $title .= $contact_info->{'first_name'} . " " . $contact_info->{'last_name'};
    } else {
        $title .= $number;
    }
    $title .= qq|</div>|;
    print OUTFILE $title;

    print OUTFILE $self->html_texts($texts);
    print OUTFILE $self->html_footer();
    close OUTFILE;
}

sub html_texts{
    my ($self, $texts) = @_;
    my $html = "";

    foreach my $text (@$texts){
        $html.= qq|<div id="|.$text->{'RowID'}.qq|" class="|.$text->{'Type'}.qq|">|.$text->{'Text'} . "</div>\n";
    }
    return $html;
}

sub html_header{
    my ($self) = @_;
    my $header = qq|<!DOCTYPE html><html lang="en"><head>
        <meta charset="utf-8" />
        <link rel="stylesheet" href="http://netdna.bootstrapcdn.com/bootstrap/3.0.3/css/bootstrap.min.css">|;
        $header .= qq|<link href="../../style.css" rel="stylesheet" type="text/css" />|;
        $header .= qq|<script src="http://code.jquery.com/jquery-latest.min.js" type="text/javascript"></script>|;
    $header .= qq|</head>\n<body>\n<div class="content">|;
    return $header;
}

sub html_footer {
    my ($self) = @_;
    return qq|</div></body></html>|;
}

sub print_title {
    my ($self, $texts, $number, $date) = @_;
    my $dt = DateTime->new(
      year       => substr($date, 0, 4),
      month      => substr($date, 4, 2),
      day        => substr($date, 6, 2),
    );
    my $title = "<h1>Conversation with $number</h1><h3>";
    $title .= $dt->day_name . " " . $dt->month_name . " " . $dt->day . ", " . $dt->year . "</h3>";
    $title .= "<h3>$texts texts</h3>";
    return $title;
}

=pod
sub process_mms {
    my ($self, $attachment_id, $number, $date) = @_;
    
    my $dbh = $self->{_sms_db};
    my $query = qq|SELECT * FROM attachment WHERE ROWID = ?|;
    my $sth = $dbh->prepare($query);
    $sth->execute($attachment_id);
    
    my $attachment = $sth->fetchrow_hashref();
    my $filepath = $attachment->{filename};
    (my $filename = $filepath) =~ s{(.*)/(.*)}{$2}xms;
    $filepath =~ s#^~/#MediaDomain-#;
    
    my $sha1_filename = sha1_hex($filepath);
    mkdir "$export_d/$number/$date" unless -d "$export_d/$number/$date";
    copy ($self->{_backup_directory} . "/" . $sha1_filename, "$export_d/$number/$date/$filename");
    
    my $html = qq|<span class="text-warning"><a href="$date/$filename">Link to attachment</a></span>|;
    if ($attachment->{mime_type} =~ /image/) {
        $html = qq|<br/><a href="$date/$filename"><img class="mms" src="$date/$filename" /></a>|;
    }
    

    return $html;
}
=cut

sub export_texts_for_number_and_date {
    my ($self, $texts, $number, $date) = @_;
    
    $number = $self->format_number($number);
    my $directory = "$export_d/$number";
    mkdir $directory unless -d $directory;
    
    open OUTFILE, ">$directory/$date.html";
    print OUTFILE $self->html_header;
    print OUTFILE qq|<div class="content">|;
    print OUTFILE $self->print_title(scalar(@$texts), $number, $date);
    print OUTFILE qq|\n<div class="text_block">|;
    foreach my $text (@$texts){
        print OUTFILE qq|\n\t<div class="$text->{Type} text"><span class="rowid">$text->{RowID}</span>|;
    	print OUTFILE qq|<span class="time">$text->{Date}:</span><span class="message">$text->{Text}|;
        if ($text->{attachment_id}) {
            print OUTFILE $self->process_mms($text->{attachment_id}, $number, $date) if $text->{attachment_id};
        }
        print OUTFILE qq|</span></div>|;
    }
    print OUTFILE qq|</div></div>\n|;
    print OUTFILE $self->html_footer;
    close OUTFILE;
}

sub _create_css_file{
    my ($self) = @_;

    if (!(-e "_export/style.css")){
        open OUTFILE, ">_export/style.css";
        print OUTFILE ".received {background-color:purple;}\n.sent{background-color:gray}";
        close OUTFILE;
    }
}

1; 
