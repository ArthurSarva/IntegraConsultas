-- CHECK accepts NULL results; explicitly reject incomplete operation metadata.
alter table audit.events drop constraint events_request_check;
alter table audit.events add constraint events_request_check check (
 (request_id is null and request_fingerprint is null) or
 (request_id is not null and request_fingerprint is not null and length(request_fingerprint)=32));
