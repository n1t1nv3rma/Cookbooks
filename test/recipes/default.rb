file "/tmp/file.crt" do
      owner 'apache'
      group 'apache'
      mode 0600
      content node["deploy"]["mycfnapp_tobedeleted"]["ssl_certificate"]
end
