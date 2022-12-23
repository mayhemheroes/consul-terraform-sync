package fuzz

import "strconv"
import "github.com/hashicorp/consul-terraform-sync/templates/tftmpl"
import "github.com/hashicorp/consul-terraform-sync/templates/hcltmpl"
import "github.com/hashicorp/consul-terraform-sync/state"

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