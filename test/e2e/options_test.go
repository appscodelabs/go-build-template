package e2e_test

import (
	"flag"
	"os"
	"path/filepath"

	"github.com/appscode/go/flags"
	logs "github.com/appscode/go/log/golog"
	"k8s.io/client-go/util/homedir"
)

type E2EOptions struct {
	KubeContext  string
	KubeConfig   string
	StorageClass string
}

var (
	options = &E2EOptions{
		KubeConfig: func() string {
			kubecfg := os.Getenv("KUBECONFIG")
			if kubecfg != "" {
				return kubecfg
			}
			return filepath.Join(homedir.HomeDir(), ".kube", "config")
		}(),
	}
)

func init() {
	//options.AddGoFlags(flag.CommandLine)
	flag.StringVar(&options.KubeConfig, "kubeconfig", options.KubeConfig, "Path to kubeconfig file with authorization information (the master location is set by the master flag).")
	flag.StringVar(&options.KubeContext, "kube-context", "", "Name of kube context")
	flag.StringVar(&options.StorageClass, "storageclass", "standard", "Storageclass for PVC")
	enableLogging()
	flag.Parse()
}

func enableLogging() {
	defer func() {
		logs.InitLogs()
		defer logs.FlushLogs()
	}()
	flag.Set("logtostderr", "true")
	logLevelFlag := flag.Lookup("v")
	if logLevelFlag != nil {
		if len(logLevelFlag.Value.String()) > 0 && logLevelFlag.Value.String() != "0" {
			return
		}
	}
	flags.SetLogLevel(2)
}
