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
        _sms_db => undef,
        _attachments => {}
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
    $self->{_attachments} = $ios_messages->get_attachments;
    my $contact_list = iOSContacts->new({backup_directory => $self->{_backup_directory}});
    my $contacts = $contact_list->get_contacts();
    foreach my $number (keys %$messages){
        #print "Exporting messages for $number\n";
	    
        mkdir "_export/$number" unless -d "$export_d/$number";

        foreach my $date (keys %{$messages->{$number}}){
            $self->create_html_file_for($number, $date, $messages->{$number}->{$date}, $contacts->{$number});
        }
    }
    return 1;
}

sub create_html_file_for{
    my ($self, $number, $date, $texts, $contact_info) = @_;
    open OUTFILE, ">_export/$number/$date.html";
    print OUTFILE $self->html_header();
    
    my $title = qq|<div class="title_header">|;
    if ($contact_info && ($contact_info->{'first_name'} || $contact_info->{'last_name'})){
        $title .= $contact_info->{'first_name'} . " " . $contact_info->{'last_name'};
    } else {
        $title .= $number;
    }
    $title .= " on ";    
    my $dateTime = DateTime->from_epoch(epoch=>$texts->[0]->{'Epoch'});
    $title .= $dateTime->day_name() .", ". $dateTime->month_name() . " " . $dateTime->day() . ", " . $dateTime->year();
    $title .= qq|</div>|;
    print OUTFILE $title;
    print OUTFILE qq|<div class="texts">|;
    print OUTFILE $self->html_texts($texts);
    print OUTFILE qq|</div>|;
    print OUTFILE $self->html_footer();
    close OUTFILE;
}

sub html_texts{
    my ($self, $texts) = @_;
    my $html = "";

    foreach my $text (@$texts){
        $html .= qq|<div id="|.$text->{'RowID'}.qq|" class="|.$text->{'Type'}.qq|">|;
        $html .= qq|<div class="time">|.$text->{'Time'}.qq|</div>|;
        $html .= qq|<div class="text">|.$text->{'Text'} . qq|</div>|;
        $html .= $self->_process_mms($text) if $text->{'AttachmentID'};
        $html .= "</div>\n";
    }
    return $html;
}

sub _process_mms {
    my ($self, $text) = @_;
    my $attachmentID = $text->{'AttachmentID'};
    my $date = $text->{'Date'};
    my $number = $text->{'UniqueID'};
    my $directory = "_export/$number/$date";
    mkdir $directory unless -d $directory;
    my $html = "";
    if ((defined $self->{_attachments}->{$attachmentID}) && (my $attachment = $self->{_attachments}->{$attachmentID})){
        copy($self->{_backup_directory}.$attachment->{'sha1_filename'}, $directory."/".$attachment->{'filename'}) or "Copy failed for file ".$self->{_backup_directory}.$attachment->{'sha1_filename'}."\n";
        if ($attachment->{'mime_type'} =~ /^image/) {
            $html = qq|<img src="|."$date/".$attachment->{'filename'}.qq|"/>|;
        } elsif ($attachment->{'mime_type'} =~ /^video/) {
            $html = qq|<video controls><source src="|."$date/".$attachment->{'filename'}.qq|"></video>|;
        } else { 
            $html = qq|<a href="|."$date/".$attachment->{'filename'}.qq|">Attachment</a>|;
        }
    }
    return $html;
}

sub html_header{
    my ($self) = @_;
    my $header = qq|<!DOCTYPE html><html lang="en"><head>
        <meta charset="utf-8" />
        <link rel="stylesheet" href="http://netdna.bootstrapcdn.com/bootstrap/3.0.3/css/bootstrap.min.css">|;
        $header .= qq|<link href="../style.css" rel="stylesheet" type="text/css" />|;
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
    $css_file .= "iOSMessageExport/style.css";
    if (!(-e "_export/style.css")){
        if (-e $css_file){
            copy($css_file, "_export/style.css");
        }else{
            open OUTFILE, ">_export/style.css";
            print OUTFILE ".received {background-color:purple;}\n.sent{background-color:gray}";
            close OUTFILE;
        }
        
    }
}

1; 
