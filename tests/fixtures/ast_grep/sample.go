// TODO: sample comment
package main

import (
	"context"
	"fmt"
)

type Point struct{ X int }

func (p Point) Show() { fmt.Println("a string") }

func helper(ch chan int, x interface{}) error {
	defer fmt.Println("done")
	go helper(ch, x)
	v, err := compute()
	if err != nil {
		return err
	}
	s := make([]int, 3)
	ch <- v
	r := <-ch
	n := x.(int)
	ctx := context.TODO()
	f := func() {}
	select {
	case <-ch:
	}
	for i := 0; i < 3; i++ {
	}
	panic(fmt.Sprintf("%v %v %v %v %v", s, r, n, ctx, f))
}
