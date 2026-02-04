select column_name
from information_schema.columns
where table_name = 'gitu_linked_accounts'
order by column_name;