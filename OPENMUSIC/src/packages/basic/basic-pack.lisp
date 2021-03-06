(in-package :om)


(let ((basicpack (omNG-make-package "Basic Tools"
                   :container-pack *om-package-tree*
                   :doc "Objects and tools for data representation and processing."
                   :subpackages 
                   (list (omNG-make-package "List Processing" 
                                            :doc ""
                                            :functions '(last-elem last-n first-n x-append flat create-list expand-lst 
                                                                   mat-trans group-list remove-dup subs-posn interlock list-modulo
                                                                   list-explode list-filter table-filter band-filter range-filter posn-match))
                         (omNG-make-package "Arithmetic" 
                                            :doc ""
                                            :functions '(om+ om- om* om/ om// om^ om-e om-abs om-min om-max
                                                             list-min list-max om-mean om-log om-round om-scale om-scale/sum reduce-tree
                                                             interpolation factorize om-random perturbation
                                                             om< om> om<= om>= om= om/=))
                         (omNG-make-package "Combinatorial" 
                                            :doc ""
                                            :functions '(sort-list rotate nth-random permut-random posn-order permutations))
                         (omNG-make-package "Series" 
                                            :doc ""
                                            :functions '(arithm-ser geometric-ser fibo-ser inharm-ser prime-ser prime? x->dx dx->x))
                         (omNG-make-package "Sets" 
                                            :doc ""
                                            :functions '(x-union x-intersect x-Xor x-diff included?))
                         (omNG-make-package "Interpolation" 
                                            :doc ""
                                            :functions '(x-transfer y-transfer om-sample linear-fun reduce-points reduce-n-points))
                         (omNG-make-package "Curves & Functions" 
                                            :doc ""
                                            :functions '(point-pairs bpf-interpol)
                                            :classes '(bpf bpc))
                         (omNG-make-package "Text" 
                                            :doc ""
                                            :functions '(textbuffer-eval textbuffer-read)
                                            :classes '(textbuffer))
                         (omNG-make-package "Containers" 
                                            :doc ""
                                            :functions nil
                                            :classes '(OMArray data-stream))
                         ))))
  ;(add-ref-section (gen-ref-entries kernelpack))
  )


;;; SPLINE
;(AddGenFun2Pack '(om-spline) *function-package*)

;;; ARRAY
;(AddGenFun2Pack '(new-comp get-comp comp-list comp-field add-comp remove-comp) *basic-data-package*)

;;; PICT
;(defvar *graphics-package*  (omNG-protect-object (omNG-make-new-package "Picture")))
;(AddClass2Pack '(picture) *graphics-package*)
;(AddGenFun2Pack '(get-RGB picture-size save-picture) *graphics-package*)



