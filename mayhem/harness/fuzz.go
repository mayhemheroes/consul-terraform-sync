package fuzz

import (
	"strconv"

	"github.com/hashicorp/consul-terraform-sync/state"
	"github.com/hashicorp/consul-terraform-sync/templates/hcltmpl"
	"github.com/hashicorp/consul-terraform-sync/templates/tftmpl"
)

func mayhemit(bytes []byte) int {
	var num int
	if len(bytes) < 1 {
		num = 0
	} else {
		num, _ = strconv.Atoi(string(bytes[0]))
	}

	switch num {
	case 0:
		tftmpl.ParseModuleVariables(bytes, "mayhem")
		return 0

	case 1:
		content := string(bytes)
		hcltmpl.ContainsDynamicTemplate(content)
		return 0

	case 2:
		content := string(bytes)
		var test state.InMemoryStore
		test.GetTask(content)
		return 0

	default:
		content := string(bytes)
		hcltmpl.ContainsVaultSecret(content)
		return 0
	}
}

func Fuzz(data []byte) int {
	_ = mayhemit(data)
	return 0
}
