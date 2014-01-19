package iOSSMSBackup;

#use base 'Exporter';
#our @EXPORT_OK = qw(new get_sms_db_filename);

use DBI;
use File::Copy;
use DateTime;
use Digest::SHA1  qw(sha1 sha1_hex sha1_base64);

my $export_d = "_export";

sub new
{
    my ($class, $params) = @_;
    my $self = {
        _backup_directory => $params->{backup_directory},
        _second_css => $params->{css},
        _sms_db_filename => '3d0d7e5fb2ce288813306e4d4636395e047a3d28',
        _sms_db => undef
    };
    
    unless (-d $self->{_backup_directory}){
        return undef;
    }
    
    bless $self, $class;
    return $self;
}


sub export_messages {
    my ($self) = @_;
    
    mkdir "_export" unless -d "_export";
    if ($self->{_second_css}) {
        copy($self->{_second_css}, "_export/$self->{_second_css}");
    }
    
    $self->connect_db;
    my $numbers = $self->get_phone_numbers();
    foreach my $number (@$numbers){
        print "Exporting messages for $number\n";
        my $dates = $self->get_dates_for_phone_number($number);
        foreach my $date (@$dates){
            my $texts = $self->get_texts_for_phone_number_for_date($number, $date);
            $self->export_texts_for_number_and_date($texts, $number, $date);
        }
    }
    return 1;
}

# Internal methods 
sub connect_db {
    my ($self) = @_;
    $self->{_sms_db} = DBI->connect( 
        "dbi:SQLite:dbname=".$self->{_backup_directory}.$self->{_sms_db_filename}, 
        "",                          
        "",                          
        { RaiseError => 1 },         
    ) or die $DBI::errstr;
}

sub get_phone_numbers {
    my ($self) = @_;
    my $dbh = $self->{_sms_db};
    my $query = qq|SELECT DISTINCT(id) FROM handle|;
    my $sth = $dbh->prepare($query);
    $sth->execute();
    my $numbers = [];
    while (my $number = $sth->fetchrow_hashref) {
        push @$numbers, $number->{'id'};
    }
    return $numbers;
}

sub get_dates_for_phone_number {
    my ($self, $number) = @_;
    my $dbh = $self->{_sms_db};
    my $query = qq|SELECT DISTINCT(strftime('%Y%m%d', date + 978307200, 'unixepoch', 'localtime')) AS date
    		    FROM message m, handle h WHERE h.rowid = m.handle_id AND h.id = ?|;
                    
    my $sth = $dbh->prepare($query);
    $sth->execute($number);
    my $dates = [];
    while (my $row = $sth->fetchrow_hashref()) {
        push @$dates, $row->{'date'};
    }
    return $dates;
    
}

sub get_texts_for_phone_number_for_date{
    my ($self, $number, $date) = @_;
    my $dbh = $self->{_sms_db};
    my $query = qq|
        SELECT 
            m.rowid as RowID, 
            CASE is_from_me 
                WHEN 0 THEN "received" 
                WHEN 1 THEN "sent" 
                ELSE "Unknown" 
            END as Type, 
            CASE 
                WHEN date > 0 then TIME(date + 978307200, 'unixepoch', 'localtime')
                ELSE NULL
            END as "Date",
            CASE 
                WHEN date > 0 THEN strftime('%Y%m%d', date + 978307200, 'unixepoch', 'localtime')
                ELSE NULL
            END as "Filename", 
            text as Text,
            maj.attachment_id 
        FROM message m
        LEFT JOIN handle h ON h.rowid = m.handle_id
        LEFT JOIN message_attachment_join maj
        ON maj.message_id = m.rowid
        WHERE h.id = ? AND Filename = ?
        ORDER BY m.rowid|;
    my $sth = $dbh->prepare($query);
    $sth->execute($number, $date);
    my $texts = [];
    
    while (my $row = $sth->fetchrow_hashref()) {
        push @$texts, $row;
    }
    return $texts;
}

sub format_number{
    my ($self, $number) = @_;
    $number =~ s/^[1+]//g;
    return $number;
}

sub html_header{
    my ($self) = @_;
    my $header = qq|<!DOCTYPE html><html lang="en"><head>
        <meta charset="utf-8" />
        <link rel="stylesheet" href="http://netdna.bootstrapcdn.com/bootstrap/3.0.3/css/bootstrap.min.css">|;
        $header .= qq|<link href="../|.$self->{_second_css}.qq|" rel="stylesheet" type="text/css" />| if $self->{_second_css};
        $header .= qq|<script src="http://code.jquery.com/jquery-latest.min.js" type="text/javascript"></script>|;
    $header .= qq|</head>\n<body>|;
    return $header;
}

sub html_footer {
    my ($self) = @_;
    return qq|</body></html>|;
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


1; 
