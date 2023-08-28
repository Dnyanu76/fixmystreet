(function(d) {
    function g(a, b) {
        this.h = d(a);
        this.g = d.extend({}, k, b);
        this.U()
    }
    var k = {
        containerHTML: '<div class="multi-select-container">',
        menuHTML: '<div class="multi-select-menu">',
        buttonHTML: '<span class="multi-select-button govuk-select">',
        menuItemsHTML: '<div class="multi-select-menuitems govuk-checkboxes--small">',
        menuItemHTML: '<div class="govuk-checkboxes__item">',
        presetsHTML: '<div class="multi-select-presets govuk-radios--small">',
        modalHTML: void 0,
        menuItemTitleClass: "multi-select-menuitem--titled",
        activeClass: "multi-select-container--open",
        noneText: "-- Select --",
        allText: void 0,
        presets: void 0,
        positionedMenuClass: "multi-select-container--positioned",
        positionMenuWithin: void 0,
        viewportBottomGutter: 20,
        menuMinHeight: 200
    };
    d.extend(g.prototype, {
        U: function() {
            this.J();
            this.S();
            this.L();
            this.K();
            this.M();
            this.P();
            this.V();
            this.W();
            this.T()
        },
        J: function() {
            if (!1 === this.h.is("select[multiple]")) throw Error("$.multiSelect only works on <select multiple> elements");
        },
        S: function() {
            this.u = d('label[for="' + this.h.attr("id") + '"]')
        },
        L: function() {
            this.j = d(this.g.containerHTML);
            this.h.data("multi-select-container", this.j);
            this.j.insertAfter(this.h)
        },
        K: function() {
            var a = this;
            this.l = d(this.g.buttonHTML);
            this.l.attr({
                role: "button",
                "aria-haspopup": "true",
                tabindex: 0,
                "aria-label": this.u.eq(0).text()
            }).on("keydown.multiselect", function(b) {
                var c = b.which;
                13 === c || 32 === c ? (b.preventDefault(), a.l.click()) : 40 === c ? (b.preventDefault(), a.C(), (a.o || a.m).children().first().focus()) : 27 === c && a.s()
            }).on("click.multiselect", function() {
                a.D()
            }).on("blur.multiselect", this.v.bind(this)).appendTo(this.j);
            this.h.on("change.multiselect", function() {
                a.G()
            });
            this.G()
        },
        G: function() {
            var a = [],
                b = [];
            this.h.find("option").each(function() {
                var c = d(this).text();
                a.push(c);
                d(this).is(":selected") && b.push(d.trim(c))
            });
            this.l.empty();
            0 == b.length ? this.l.text(this.g.noneText) : b.length === a.length && this.g.allText ? this.l.text(this.g.allText) : this.l.text(b.join(", "))
        },
        M: function() {
            var a = this;
            this.i = d(this.g.menuHTML);
            this.i.attr({
                role: "menu"
            }).on("keyup.multiselect", function(b) {
                27 === b.which && (a.s(), a.l.focus())
            }).appendTo(this.j);
            this.N();
            this.g.presets && this.R()
        },
        N: function() {
            var a = this;
            this.m = d(this.g.menuItemsHTML);
            this.i.append(this.m);
            this.h.on("change.multiselect", function(b, c) {
                !0 !== c && a.H()
            });
            this.H()
        },
        H: function() {
            var a = this;
            this.m.empty();
            this.h.children("optgroup,option").each(function(b, c) {
                "OPTION" === c.nodeName ? (b = a.B(d(c), b), a.m.append(b)) : a.O(d(c), b)
            })
        },
        F: function(a, b) {
            var c = b.which;
            38 === c ? (b.preventDefault(), b = d(b.currentTarget).prev(), b.length ? b.focus() : this.o && "menuitem" === a ? this.o.children().last().focus() :
                this.l.focus()) : 40 === c && (b.preventDefault(), b = d(b.currentTarget).next(), b.length || "menuitem" === a ? b.focus() : this.m.children().first().focus())
        },
        R: function() {
            var a = this;
            this.o = d(this.g.presetsHTML);
            this.i.prepend(this.o);
            d.each(this.g.presets, function(b, c) {
                b = a.h.attr("name") + "_preset_" + b;
                var f = d(a.g.menuItemHTML).attr({
                    "for": b,
                    role: "menuitem"
                }).appendTo(a.o);
                labelRadio = d("<label>").attr({
                  class: "govuk-label govuk-radios__label",
                  "for": b,
                  role: "menuitem"
                }).prependTo(f);
                labelRadio.text(" " + c.name).on("keydown.multiselect", a.F.bind(a, "preset"));
                b = d("<input>").attr({
                    class: "govuk-radios__input",
                    type: "radio",
                    name: a.h.attr("name") + "_presets",
                    id: b
                }).prependTo(f);
  
                c.all && (c.options = [], a.h.find("option").each(function() {
                    var e = d(this).val();
                    c.options.push(e)
                }));
                b.on("change.multiselect", function() {
                    a.h.val(c.options);
                    a.h.trigger("change")
                }).on("blur.multiselect", a.v.bind(a))
            });
            this.h.on("change.multiselect", function() {
                a.I()
            });
            this.I()
        },
        I: function() {
            var a = this;
            d.each(this.g.presets, function(b, c) {
                b = a.h.attr("name") + "_preset_" + b;
                b = a.o.find("#" + b);
                a: {
                    c = c.options || [];
                    var f = a.h.val() || [];
                    if (c.length != f.length) c = !1;
                    else {
                        c.sort();
                        f.sort();
                        for (var e = 0; e < c.length; e++)
                            if (c[e] !==
                                f[e]) {
                                c = !1;
                                break a
                            } c = !0
                    }
                }
                c ? b.prop("checked", !0) : b.prop("checked", !1)
            })
        },
        O: function(a, b) {
            var c = this;
            a.children("option").each(function(f, e) {
                e = c.B(d(e), b + "_" + f);
                var h = c.g.menuItemTitleClass;
                0 !== f && (h += "sr");
                e.addClass(h).attr("data-group-title", a.attr("label"));
                c.m.append(e)
            })
        },
        B: function(a, b) {
            var c = this.h.attr("name") + "_" + b;
            b = d(this.g.menuItemHTML).attr({
                "for": c,
                role: "menuitem"
            }).on("keydown.multiselect", this.F.bind(this, "menuitem"));
            labelCheckbox = d("<label>").attr({
              class: "govuk-label govuk-checkboxes__label",
              "for": c,
              role: "menuitem"
            }).prependTo(b);
            labelCheckbox.text(" " + a.text());
            c = d("<input>").attr({
                class: "govuk-checkboxes__input",
                type: "checkbox",
                id: c,
                value: a.val()
            }).prependTo(b);
            a.is(":disabled") && c.attr("disabled", "disabled");
            a.is(":selected") && c.prop("checked", "checked");
            c.on("change.multiselect", function() {
                d(this).prop("checked") ? a.prop("selected", !0) : a.prop("selected", !1);
                a.trigger("change", [!0])
            }).on("blur.multiselect", this.v.bind(this));
            return b
        },
        P: function() {
            var a = this;
            this.g.modalHTML && (this.A = d(this.g.modalHTML), this.A.on("click.multiselect", function() {
                a.s()
            }), this.A.insertBefore(this.i))
        },
        V: function() {
            var a = this;
            d("html").on("click.multiselect", function() {
                a.s()
            });
            this.j.on("click.multiselect", function(b) {
                b.stopPropagation()
            })
        },
        W: function() {
            var a = this;
            this.u.on("click.multiselect", function(b) {
                b.preventDefault();
                b.stopPropagation();
                a.D()
            })
        },
        T: function() {
            this.h.hide()
        },
        C: function() {
            d("html").trigger("click.multiselect");
            this.j.addClass(this.g.activeClass);
            if (this.g.positionMenuWithin && this.g.positionMenuWithin instanceof d) {
                var a = this.i.offset().left + this.i.outerWidth(),
                    b = this.g.positionMenuWithin.offset().left + this.g.positionMenuWithin.outerWidth();
                a > b && (this.i.css("width", b - this.i.offset().left), this.j.addClass(this.g.positionedMenuClass))
            }
            a = this.i.offset().top + this.i.outerHeight();
            b = d(window).scrollTop() + d(window).height();
            a > b - this.g.viewportBottomGutter ? this.i.css({
                maxHeight: Math.max(b - this.g.viewportBottomGutter - this.i.offset().top, this.g.menuMinHeight),
                overflow: "scroll"
            }) : this.i.css({
                maxHeight: "",
                overflow: ""
            })
        },
        s: function() {
            this.j.removeClass(this.g.activeClass);
            this.j.removeClass(this.g.positionedMenuClass);
            this.i.css("width", "auto")
        },
        D: function() {
            this.j.hasClass(this.g.activeClass) ? this.s() : this.C()
        },
        v: function(a) {
            a.relatedTarget && !d(a.relatedTarget).closest(this.j).length && this.s()
        }
    });
    d.fn.multiSelect = function(a) {
        return this.each(function() {
            d.data(this, "plugin_multiSelect") || d.data(this, "plugin_multiSelect", new g(this, a))
        })
    }
  })(jQuery);
