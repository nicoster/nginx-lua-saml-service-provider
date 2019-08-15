NGINXPATH = /usr/local/opt/openresty/nginx/sbin:/usr/local/openresty/nginx/sbin
IDP_HOST=idp.ssocircle.com
IDP_PORT=443


sync:
	time (for d in lib/ Makefile lua/ conf/ html/ bin/ plugins/; do rsync -rP $$d $(TARGET):$(DST_DIR)/$$d & done; wait)

kill:
	kill `cat logs/nginx.pid` 2&>/dev/null || true
	@$(MAKE) ps

ps:
	ps aux | grep ' nginx' |grep -v grep || true

	

.live:;$(eval DAEMON_FLAG = off) 
live: .live run

run: kill
	$(eval DAEMON_FLAG ?= on)
	sleep 1
	PATH=$(NGINXPATH):${PATH} nginx -p `pwd` -c conf/nginx.conf -g 'daemon $(DAEMON_FLAG); master_process $(DAEMON_FLAG);'
	tail logs/error.log


log:
	tail -f logs/error.log