package iOSSMSBackup;

#use base 'Exporter';
#our @EXPORT_OK = qw(new get_sms_db_filename);

use DBI;

sub new
{
    my $class = shift;
    my $self = {
        _backup_directory => shift,
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
    $self->connect_db;
    my $texts = $self->get_texts_for_phone_number_for_date('+17347758413', '20131216');
    foreach my $text (@$texts) {
          print "Row fetched ".$text->{'Filename'}."\n";
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

1; 
