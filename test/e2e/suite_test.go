package e2e_test

import (
	"fmt"
	"testing"
	"time"

	logs "github.com/appscode/go/log/golog"
	. "github.com/onsi/ginkgo"
	"github.com/onsi/ginkgo/reporters"
	. "github.com/onsi/gomega"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/discovery"
	"k8s.io/client-go/kubernetes"
	discovery_util "kmodules.xyz/client-go/discovery"
	"kmodules.xyz/client-go/tools/clientcmd"
)

const (
	TIMEOUT = 20 * time.Minute
)

func TestE2e(t *testing.T) {
	logs.InitLogs()
	RegisterFailHandler(Fail)
	SetDefaultEventuallyTimeout(TIMEOUT)
	junitReporter := reporters.NewJUnitReporter("junit.xml")
	RunSpecsWithDefaultAndCustomReporters(t, "e2e Suite", []Reporter{junitReporter})
}

var _ = BeforeSuite(func() {
	cfg, err := clientcmd.BuildConfigFromContext(options.KubeConfig, options.KubeContext)
	Expect(err).NotTo(HaveOccurred())

	discClient, err := discovery.NewDiscoveryClientForConfig(cfg)
	Expect(err).NotTo(HaveOccurred())
	serverVersion, err := discovery_util.GetBaseVersion(discClient)
	Expect(err).NotTo(HaveOccurred())
	fmt.Println("serverVersion = ", serverVersion)

	kc, err := kubernetes.NewForConfig(cfg)
	Expect(err).NotTo(HaveOccurred())
	nodes, err := kc.CoreV1().Nodes().List(metav1.ListOptions{})
	Expect(err).NotTo(HaveOccurred())
	for _, node := range nodes.Items {
		fmt.Println(node.Name)
	}
})

var _ = AfterSuite(func() {
	var err error
	Expect(err).NotTo(HaveOccurred())
})
