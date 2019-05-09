#!/bin/bash -xe

apt-get update
apt-get install -y apache2 libapache2-mod-php

cat > /var/www/html/index.php <<'EOF'
<?php
function metadata_value($value) {
    $opts = [
        "http" => [
            "method" => "GET",
            "header" => "Metadata-Flavor: Google"
        ]
    ];
    $context = stream_context_create($opts);
    $content = file_get_contents("http://metadata/computeMetadata/v1/$value", false, $context);
    return $content;
}
if ($_SERVER['HTTP_X_FORWARDED_PROTO'] == "http") {
		$redirect = 'https://' . $_SERVER['HTTP_HOST'] . $_SERVER['REQUEST_URI'];
		header('HTTP/1.1 301 Moved Permanently');
		header('Location: ' . $redirect);
		exit();
}
?>

<!doctype html>
<html>
<head>
<!-- Compiled and minified CSS -->
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/materialize/0.97.0/css/materialize.min.css">

<!-- Compiled and minified JavaScript -->
<script src="https://cdnjs.cloudflare.com/ajax/libs/materialize/0.97.0/js/materialize.min.js"></script>
<style>
img {
  display: block;
  margin-left: auto;
  margin-right: auto;
}
</style>
<title>RGA Demo App</title>
</head>
<body>
<div class="container">
  <div class="row">
    <div class="col s2">&nbsp;</div>
    <div class="col s8">
    
    <p><img src="/static/meme.jpg" align="middle" style="width:100%"/></p>

    <p><a href="/static/motd.html">Click here another static page on GCS.</a></p>

<div class="card blue">
<div class="card-content white-text">
<div class="card-title">VM Instance</div>
</div>
<div class="card-content white">
<table class="bordered">
  <tbody>
	<tr>
	  <td>Name</td>
	  <td><?php printf(metadata_value("instance/name")) ?></td>
	</tr>
	<tr>
	  <td>Internal IP</td>
	  <td><?php printf(metadata_value("instance/network-interfaces/0/ip")) ?></td>
	</tr>
	<tr>
	  <td>External IP</td>
	  <td><?php printf(metadata_value("instance/network-interfaces/0/access-configs/0/external-ip")) ?></td>
	</tr>
  </tbody>
</table>
</div>
</div>

<div class="card blue">
<div class="card-content white-text">
<div class="card-title">GCP Loadbalancer</div>
</div>
<div class="card-content white">
<table class="bordered">
  <tbody>
	<tr>
	  <td>Address</td>
	  <td><?php printf($_SERVER["HTTP_HOST"]); ?></td>
	</tr>
  </tbody>
</table>
</div>

</div>
</div>
<div class="col s2">&nbsp;</div>
</div>
</div>
</html>
EOF
sudo mv /var/www/html/index.html /var/www/html/index.html.old

[[ -n "${PROXY_PATH}" ]] && mkdir -p /var/www/html/${PROXY_PATH} && cp /var/www/html/index.php /var/www/html/${PROXY_PATH}/index.php

systemctl enable apache2
systemctl restart apache2
