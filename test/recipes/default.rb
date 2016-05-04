file "/tmp/file.crt" do
      owner 'apache'
      group 'apache'
      mode 0600
      content node["deploy"]["javambedeleted"]["ssl_certificate"]
end
