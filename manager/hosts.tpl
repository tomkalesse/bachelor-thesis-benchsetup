opendatacube:
  client_host: http://${odc_client_ip}:8080/request
  sut_host: http://${odc_sut_ip}:8080/query

rasdaman:
  client_host: http://${rasdaman_client_ip}:8080/request
  sut_host: http://${rasdaman_sut_ip}:8080/rasdaman/ows
