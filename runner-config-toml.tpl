concurrent = 12

[[runners]]
    name = "${name}"
    url = "https://gitlab.company.com"
    token = "${token}"
    output_limit = 10000
    executor = "kubernetes"
    [runners.kubernetes]
        namespace = "${namespace}"
        privilaged = true
        image_pull_secrets = ["${docker_pull_secret}"]
        cpu_request = "1"
        memory_request = "1Gi"
        cpu_limit = "2"
        memory_limit = "2Gi"
        [runners.kubernetes.dns.config]
            nameservers = ["xx.xx.xx.xx"]
            searches = ["gitlab.company.com"]
        [[runners.kubernetes.host_aliases]]
            ip = "xx.xx.xx.xx"
            hostname = ["gitlab.company.com"]
        [[runners.kubernetes.host_aliases]]
            ip = "xx.xx.xx.xx"
            hostname = ["artifactory.company.com"]
        [[runners.kubernetes.volume.host_path]]
            name = "m2_dir"
            mount_path = "./m2"
            host_path = "/mnt/.m2"
            read_only = false
